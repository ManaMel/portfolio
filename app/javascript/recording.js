// recording.js
import { encodeAudio } from "./encode-audio";
import WaveSurfer from "wavesurfer.js";

document.addEventListener("turbo:load", async function recording() {
  if (window.__audioInitialized__) return;
  window.__audioInitialized__ = true;

  try {
    // --- 要素 ---
    const buttonStart = document.querySelector('#buttonStart');
    const buttonStop  = document.querySelector('#buttonStop');
    const buttonSave  = document.querySelector('#buttonSave');
    const buttonPlay  = document.querySelector('#buttonPlay');
    const waveformContainer = document.querySelector('#waveform');

    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');
    const echoDelaySlider = document.querySelector('#echoDelay');
    const echoFeedbackSlider = document.querySelector('#echoFeedback');

    // 必須要素チェック
    if (!buttonStart || !buttonStop || !buttonSave || !buttonPlay) {
      console.warn('録音ボタン要素が見つかりません。スクリプトを中断します。');
      return;
    }

    // --- AudioContext & Worklet --- (1回だけ)
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    await audioContext.audioWorklet.addModule('/audio-recorder.js');

    // --- WaveSurfer 初期化（波形表示用） ---
    let wavesurfer = null;
    if (waveformContainer) {
      wavesurfer = WaveSurfer.create({
        container: waveformContainer,
        audioContext: audioContext, // optional, but we use WaveSurfer only for visualization
        backend: 'WebAudio',
        waveColor: 'rgb(200,0,200)',
        progressColor: 'rgb(120,0,120)',
        cursorColor: '#333',
        height: 96,
        responsive: true,
      });
    }

    // --- グローバル再生パイプラインノード（リアルタイム調整に使う） ---
    // echo / reverb / gain のノード群をアプリ全体で一度だけ作る
    const playbackGain = audioContext.createGain(); // 最終マスター
    const convolver = audioContext.createConvolver(); // IR-based reverb
    const reverbDryGain = audioContext.createGain();
    const reverbWetGain = audioContext.createGain();
    const reverbInput = audioContext.createGain();

    const delayNode = audioContext.createDelay(5.0); // echo
    const feedbackGain = audioContext.createGain();
    const echoWetGain = audioContext.createGain();
    const echoDryGain = audioContext.createGain();
    const echoInput = audioContext.createGain();

    // 接続（固定構造）
    echoInput.connect(echoDryGain);
    echoInput.connect(delayNode);

    delayNode.connect(feedbackGain);
    feedbackGain.connect(delayNode); // feedback loop
    delayNode.connect(echoWetGain);

    echoDryGain.connect(reverbInput);
    echoWetGain.connect(reverbInput);

    reverbInput.connect(reverbDryGain);
    reverbInput.connect(convolver);
    convolver.connect(reverbWetGain);

    reverbDryGain.connect(playbackGain);
    reverbWetGain.connect(playbackGain);

    playbackGain.connect(audioContext.destination);

    // デフォルト値
    playbackGain.gain.value = 1.0;
    delayNode.delayTime.value = 0.25;
    feedbackGain.gain.value = 0.3;
    reverbWetGain.gain.value = 0.0;
    reverbDryGain.gain.value = 1.0;
    echoWetGain.gain.value = 0.5;
    echoDryGain.gain.value = 0.5;

    // --- IR (インパルス応答) の事前読み込み ---
    // IR を事前に読み込み、 convolver.buffer にセットしておく
    let irBuffer = null;
    try {
      irBuffer = await fetch('/1 Halls 01 Large Hall_16bit.wav')
        .then(r => { if (!r.ok) throw new Error('IR fetch failed ' + r.status); return r.arrayBuffer(); })
        .then(buf => audioContext.decodeAudioData(buf));
      convolver.buffer = irBuffer;
      console.log('IR（リバーブ）読み込み成功');
    } catch (err) {
      console.warn('IR 読み込みに失敗:', err);
      // 失敗しても進められる（convolver.buffer が null ならリバーブ無効）
    }

    // --- 録音準備（AudioWorkletNode で録音データを受け取る） ---
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const [track] = stream.getAudioTracks();
    const settings = track.getSettings();
    const mediaStreamSource = audioContext.createMediaStreamSource(stream);
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder'); // あなたの worklet

    // バッファをチャンクで集める（AudioWorklet 側から ArrayBuffer 等で送られてくる想定）
    const buffers = [];
    audioRecorder.port.onmessage = (event) => {
      let data = event.data;
      if (data instanceof ArrayBuffer) data = new Float32Array(data);
      buffers.push(data);
    };

    // 録音時は録音ワークレットへだけ接続（スピーカーへは出さない）
    mediaStreamSource.connect(audioRecorder);

    // 再生用の保持バッファ・状態
    let currentDecodeBuffer = null;   // 録音した『未加工』の AudioBuffer
    let activeSource = null;          // 再生中の AudioBufferSourceNode
    let processedBuffer = null;       // （Optional）最後に Offline で作った加工済みバッファ

    // ---- ユーティリティ関数 ----

    // 再生（リアルタイム経路）: 毎回新しい BufferSource を作って echoInput に接続する
    function playProcessedAudio(bufferToPlay) {
      if (!bufferToPlay) return;
      // 停止
      if (activeSource) {
        try { activeSource.stop(); } catch (e) { /* ignore */ }
        try { activeSource.disconnect(); } catch (e) { /* ignore */ }
        activeSource = null;
      }

      const source = audioContext.createBufferSource();
      source.buffer = bufferToPlay;
      // ここでグローバル echoInput に送れば、echo→reverb→playbackGain の流れで再生される
      source.connect(echoInput);
      source.start();
      activeSource = source;
      console.log("▶ 再生開始（リアルタイムパイプライン）");
    }

    // Offline で「現在のスライダー設定（wet/dry / delay / feedback / gain）」を反映した AudioBuffer を作る
    // これを保存時や波形更新時に使う。返り値は AudioBuffer（OfflineAudioContext のレンダリング結果）
    async function renderOfflineWithCurrentSettings(inputBuffer) {
      if (!inputBuffer) return null;
      const channels = inputBuffer.numberOfChannels || 1;
      const offlineCtx = new OfflineAudioContext(
        channels,
        inputBuffer.length,
        inputBuffer.sampleRate
      );

      // source
      const src = offlineCtx.createBufferSource();
      src.buffer = inputBuffer;

      // offline 用のノード群（同様の配線を作る）
      const offEchoInput = offlineCtx.createGain();
      const offEchoDry = offlineCtx.createGain();
      const offDelay = offlineCtx.createDelay(5.0);
      const offFeedback = offlineCtx.createGain();
      const offEchoWet = offlineCtx.createGain();

      const offReverbIn = offlineCtx.createGain();
      const offReverbDry = offlineCtx.createGain();
      const offConvolver = offlineCtx.createConvolver();
      const offReverbWet = offlineCtx.createGain();

      const offMaster = offlineCtx.createGain();

      // copy IR if available
      if (irBuffer) {
        // decodeAudioData の result (AudioBuffer) をコピー into offline convolver
        // Note: You can assign the same AudioBuffer reference (works in most browsers).
        offConvolver.buffer = irBuffer;
      }

      // set values from current live nodes (take snapshot)
      offDelay.delayTime.value = delayNode.delayTime.value;
      offFeedback.gain.value = feedbackGain.gain.value;
      offEchoWet.gain.value = echoWetGain.gain.value;
      offEchoDry.gain.value = echoDryGain.gain.value;
      offReverbWet.gain.value = reverbWetGain.gain.value;
      offReverbDry.gain.value = reverbDryGain.gain.value;
      offMaster.gain.value = playbackGain.gain.value;

      // connect offline graph (same topology)
      offEchoInput.connect(offEchoDry);
      offEchoInput.connect(offDelay);

      offDelay.connect(offFeedback);
      offFeedback.connect(offDelay);
      offDelay.connect(offEchoWet);

      offEchoDry.connect(offReverbIn);
      offEchoWet.connect(offReverbIn);

      offReverbIn.connect(offReverbDry);
      offReverbIn.connect(offConvolver);
      offConvolver.connect(offReverbWet);

      offReverbDry.connect(offMaster);
      offReverbWet.connect(offMaster);
      offMaster.connect(offlineCtx.destination);

      // wire source
      src.connect(offEchoInput);

      src.start(0);
      const rendered = await offlineCtx.startRendering();
      return rendered;
    }

    // WAV 化してダウンロード（encodeAudio を利用）
    function downloadRenderedBufferAsWav(audioBuffer, filename = 'recording_processed.wav') {
      if (!audioBuffer) return;
      // collect channels
      const out = [];
      for (let ch = 0; ch < audioBuffer.numberOfChannels; ch++) {
        out.push(Float32Array.from(audioBuffer.getChannelData(ch)));
      }
      const blob = encodeAudio(out, { sampleRate: audioBuffer.sampleRate });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    }

    // --- UI イベントハンドラ ---

    // 録音開始
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume();
      buttonStart.disabled = true;
      buttonStop.disabled = false;
      buttonSave.disabled = true;
      buffers.splice(0, buffers.length);
      if (wavesurfer) wavesurfer.empty();

      // 音声ワークレットに録音開始フラグを渡す（あなたの worklet が isRecording パラメータで動く設計）
      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(1, audioContext.currentTime);
      console.log('録音開始');
    });

    // 録音停止
    buttonStop.addEventListener('click', async () => {
      buttonStop.disabled = true;
      buttonStart.disabled = false;
      buttonSave.disabled = false;

      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(0, audioContext.currentTime);

      // encodeAudio に渡す形式に合わせ、Float32Array の連結を行い AudioBuffer を作る
      const totalLen = buffers.reduce((s, b) => s + b.length, 0);
      const outBuf = audioContext.createBuffer(1, totalLen, audioContext.sampleRate);
      const channel = outBuf.getChannelData(0);
      let offset = 0;
      for (const chunk of buffers) {
        channel.set(chunk, offset);
        offset += chunk.length;
      }
      currentDecodeBuffer = outBuf;

      // WaveSurfer に未加工（録音直後）の波形を表示
      if (wavesurfer) {
        const blobForWave = (function() {
          // reuse encodeAudio: expects array of Float32Array (mono)
          const arr = [Float32Array.from(currentDecodeBuffer.getChannelData(0))];
          return encodeAudio(arr, { sampleRate: currentDecodeBuffer.sampleRate });
        })();
        const url = URL.createObjectURL(blobForWave);
        wavesurfer.load(url);
      }

      console.log("録音停止。AudioBuffer準備OK");
      // 自動で再生（リアルタイム経路）して確認したければ呼ぶ
      // playProcessedAudio(currentDecodeBuffer);
    });

    // 再生ボタン（再生はリアルタイムパイプラインを通す）
    buttonPlay.addEventListener('click', () => {
      if (!currentDecodeBuffer) {
        console.warn('再生する録音がありません');
        return;
      }
      playProcessedAudio(currentDecodeBuffer);
    });

    // スライダー：各ノードへ即時反映
    volumeSlider?.addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      playbackGain.gain.setValueAtTime(v, audioContext.currentTime);
    });

    reverbSlider?.addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      // dry/wet ミックス（ここは好みで変える）
      reverbWetGain.gain.setValueAtTime(v, audioContext.currentTime);
      reverbDryGain.gain.setValueAtTime(1 - v, audioContext.currentTime);
    });

    echoDelaySlider?.addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      delayNode.delayTime.setValueAtTime(v, audioContext.currentTime);
    });

    echoFeedbackSlider?.addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      feedbackGain.gain.setValueAtTime(v * 0.9, audioContext.currentTime);
      echoWetGain.gain.setValueAtTime(v, audioContext.currentTime);
      echoDryGain.gain.setValueAtTime(1 - v, audioContext.currentTime);
    });

    // 保存（現在の設定でオフラインでレンダリングしてダウンロード）
    buttonSave.addEventListener('click', async () => {
      if (!currentDecodeBuffer) return;
      console.log('オフラインレンダリング開始...');
      const rendered = await renderOfflineWithCurrentSettings(currentDecodeBuffer);
      if (!rendered) {
        console.warn('レンダリングに失敗しました');
        return;
      }
      downloadRenderedBufferAsWav(rendered, 'recording_reverb_echo.wav');
      console.log('保存完了');
    });

    // オプション：加工済みを波形に反映（WaveSurfer 上で“加工後”波形を見たいとき）
    // 使いたければ UI にボタンを作ってこれを呼ぶ
    async function updateWaveformToProcessed() {
      if (!currentDecodeBuffer) return;
      const rendered = await renderOfflineWithCurrentSettings(currentDecodeBuffer);
      if (!rendered) return;
      const arr = [];
      for (let ch = 0; ch < rendered.numberOfChannels; ch++) {
        arr.push(Float32Array.from(rendered.getChannelData(ch)));
      }
      const blob = encodeAudio(arr, { sampleRate: rendered.sampleRate });
      if (wavesurfer) wavesurfer.load(URL.createObjectURL(blob));
    }

    // --- cleanup for turbo ---
    document.addEventListener("turbo:before-cache", () => {
      try {
        audioContext.close();
      } catch (e){}
      window.__audioInitialized__ = false;
      console.log("AudioContext closed and flag reset");
    });

  } catch (err) {
    console.error(err);
  }
});
