// recording.js
import { encodeAudio } from "./encode-audio";
import WaveSurfer from "wavesurfer.js";

document.addEventListener("turbo:load", async function recording() {
  if (window.__audioInitialized__) return;
  window.__audioInitialized__ = true;

  try {
    // -------------------
    // --- DOM要素取得 ---
    // -------------------
    const buttonStart = document.querySelector('#buttonStart');
    const buttonStop  = document.querySelector('#buttonStop');
    const buttonSave  = document.querySelector('#save-recording-btn');
    const buttonPlay  = document.querySelector('#buttonPlay');
    const waveformContainer = document.querySelector('#waveform');

    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');
    const echoDelaySlider = document.querySelector('#echoDelay');
    const echoFeedbackSlider = document.querySelector('#echoFeedback');

    if (!buttonStart || !buttonStop || !buttonSave || !buttonPlay) return;

    // -------------------
    // --- AudioContext ---
    // -------------------
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();

    // Worklet モジュールを読み込む（/audio-recorder.js を public に配置している想定）
    await audioContext.audioWorklet.addModule('/audio-recorder.js');
    console.log("AudioWorklet loaded");

    // -------------------
    // --- WaveSurfer ---
    // -------------------
    let wavesurfer = null;
    if (waveformContainer) {
      wavesurfer = WaveSurfer.create({
        container: waveformContainer,
        audioContext: audioContext,
        backend: 'WebAudio',
        waveColor: 'rgb(200,0,200)',
        progressColor: 'rgb(120,0,120)',
        cursorColor: '#333',
        height: 96,
        responsive: true,
      });
    }

    // -------------------
    // --- エフェクトノード（ライブ再生用） ---
    // -------------------
    const playbackGain = audioContext.createGain();

    const convolver = audioContext.createConvolver();
    const reverbDryGain = audioContext.createGain();
    const reverbWetGain = audioContext.createGain();
    const reverbInput = audioContext.createGain();

    const delayNode = audioContext.createDelay(5.0);
    const feedbackGain = audioContext.createGain();
    const echoWetGain = audioContext.createGain();
    const echoDryGain = audioContext.createGain();
    const echoInput = audioContext.createGain();

    // 接続順（ライブ）
    echoInput.connect(echoDryGain);
    echoInput.connect(delayNode);
    delayNode.connect(feedbackGain);
    feedbackGain.connect(delayNode); // フィードバックループ
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

    // -------------------
    // --- IR (reverb) 読み込み ---
    // public に置いてある '/1 Halls 01 Large Hall_16bit.wav' を使う想定
    // -------------------
    let irBuffer = null;
    try {
      const buf = await fetch('/1 Halls 01 Large Hall_16bit.wav').then(r => {
        if (!r.ok) throw new Error('IR fetch failed: ' + r.status);
        return r.arrayBuffer();
      });
      irBuffer = await audioContext.decodeAudioData(buf);
      convolver.buffer = irBuffer;
      console.log('IR 読み込み成功');
    } catch (err) {
      console.warn('IR 読み込み失敗', err);
    }

    // -------------------
    // --- 録音準備 (入力取得) ---
    // -------------------
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mediaStreamSource = audioContext.createMediaStreamSource(stream);

    // Worklet を作り、raw PCM を受け取る（worklet 側で Float32Array を postMessage している想定）
    let rawBuffers = []; // 録音中に蓄積する Float32Array の配列
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder');
    audioRecorder.port.onmessage = (e) => {
      let data = e.data;
      if (data instanceof ArrayBuffer) data = new Float32Array(data);
      rawBuffers.push(data);
    };

    // 入力を worklet -> 加工パイプラインへ流す（ライブでモニタリング）
    mediaStreamSource.connect(audioRecorder);
    audioRecorder.connect(echoInput); // 録音時に同時にエフェクトをかけてモニタリングできる

    // --- 再生用変数 ---
    let currentDecodeBuffer = null;
    let activeSource = null;

    function playProcessedAudio(buffer) {
      if (!buffer) return;
      if (activeSource) {
        try { activeSource.stop(); } catch {}
        try { activeSource.disconnect(); } catch {}
        activeSource = null;
      }
      const source = audioContext.createBufferSource();
      source.buffer = buffer;
      // ライブの再生パイプラインを通して鳴らす（playbackGain が最終）
      source.connect(echoInput); // echoInput -> ... -> playbackGain -> destination
      source.start();
      activeSource = source;
    }

    // -------------------
    // --- スライダー操作 ---
    // -------------------
    volumeSlider?.addEventListener('input', e => playbackGain.gain.setValueAtTime(parseFloat(e.target.value), audioContext.currentTime));
    reverbSlider?.addEventListener('input', e => {
      const v = parseFloat(e.target.value);
      reverbWetGain.gain.setValueAtTime(v, audioContext.currentTime);
      reverbDryGain.gain.setValueAtTime(1 - v, audioContext.currentTime);
    });
    echoDelaySlider?.addEventListener('input', e => delayNode.delayTime.setValueAtTime(parseFloat(e.target.value), audioContext.currentTime));
    echoFeedbackSlider?.addEventListener('input', e => {
      const v = parseFloat(e.target.value);
      feedbackGain.gain.setValueAtTime(v * 0.9, audioContext.currentTime);
      echoWetGain.gain.setValueAtTime(v, audioContext.currentTime);
      echoDryGain.gain.setValueAtTime(1 - v, audioContext.currentTime);
    });

    // -------------------
    // --- 録音停止時: OfflineAudioContext で「同じ」エフェクトをかける → WAV化 ---
    // -------------------
    async function renderOfflineAndMakeWavBlob(rawBuffersConcat, sampleRate) {
      // rawBuffersConcat: Float32Array（モノラル想定）
      if (!rawBuffersConcat || rawBuffersConcat.length === 0) return null;

      // OfflineAudioContext を使って、ライブと同じ設定で加工を掛ける
      const numberOfChannels = 1;
      const length = rawBuffersConcat.length;
      const offlineCtx = new OfflineAudioContext(numberOfChannels, length, sampleRate);

      // source
      const src = offlineCtx.createBufferSource();
      const buffer = offlineCtx.createBuffer(numberOfChannels, length, sampleRate);
      buffer.getChannelData(0).set(rawBuffersConcat);
      src.buffer = buffer;

      // --- offline のノード群（ライブと同じ構成） ---
      const offPlaybackGain = offlineCtx.createGain();

      const offConvolver = offlineCtx.createConvolver();
      const offReverbDry = offlineCtx.createGain();
      const offReverbWet = offlineCtx.createGain();
      const offReverbInput = offlineCtx.createGain();

      const offDelay = offlineCtx.createDelay(5.0);
      const offFeedback = offlineCtx.createGain();
      const offEchoWet = offlineCtx.createGain();
      const offEchoDry = offlineCtx.createGain();
      const offEchoInput = offlineCtx.createGain();

      // copy IR if exists
      if (irBuffer) {
        try {
          // IR is an AudioBuffer from live context; reusing reference usually works
          offConvolver.buffer = irBuffer;
        } catch (e) {
          console.warn("Offline convolver buffer copy failed", e);
        }
      }

      // copy current live parameter values (snapshot)
      offPlaybackGain.gain.value = playbackGain.gain.value;
      offDelay.delayTime.value = delayNode.delayTime.value;
      offFeedback.gain.value = feedbackGain.gain.value;
      offEchoWet.gain.value = echoWetGain.gain.value;
      offEchoDry.gain.value = echoDryGain.gain.value;
      offReverbWet.gain.value = reverbWetGain.gain.value;
      offReverbDry.gain.value = reverbDryGain.gain.value;

      // connect offline graph (same topology)
      offEchoInput.connect(offEchoDry);
      offEchoInput.connect(offDelay);

      offDelay.connect(offFeedback);
      offFeedback.connect(offDelay);
      offDelay.connect(offEchoWet);

      offEchoDry.connect(offReverbInput);
      offEchoWet.connect(offReverbInput);

      offReverbInput.connect(offReverbDry);
      offReverbInput.connect(offConvolver);
      offConvolver.connect(offReverbWet);

      offReverbDry.connect(offPlaybackGain);
      offReverbWet.connect(offPlaybackGain);

      offPlaybackGain.connect(offlineCtx.destination);

      // wire source -> offEchoInput
      src.connect(offEchoInput);

      // start and render
      src.start(0);
      const renderedBuffer = await offlineCtx.startRendering();

      // WAV 化（encodeAudio expects Float32Array per channel）
      const out = [];
      for (let ch = 0; ch < renderedBuffer.numberOfChannels; ch++) {
        out.push(Float32Array.from(renderedBuffer.getChannelData(ch)));
      }
      const wavBlob = encodeAudio(out, { sampleRate: renderedBuffer.sampleRate });
      return { wavBlob, renderedBuffer };
    }

    // -------------------
    // --- 録音の開始/停止 ---
    // -------------------
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume();
      buttonStart.disabled = true;
      buttonStop.disabled = false;
      buttonSave.disabled = true;
      rawBuffers = [];
      if (wavesurfer) wavesurfer.empty();

      // Worklet に録音フラグ送る（worklet が isRecording を監視する設計）
      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(1, audioContext.currentTime);

      console.log('録音開始');
    });

    buttonStop.addEventListener('click', async () => {
      buttonStop.disabled = true;
      buttonStart.disabled = false;
      buttonSave.disabled = false;

      // stop recording flag in worklet
      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(0, audioContext.currentTime);

      // concat rawBuffers -> single Float32Array (mono)
      let totalLen = rawBuffers.reduce((s, b) => s + b.length, 0);
      if (totalLen === 0) {
        alert("録音データがありません");
        return;
      }
      const combined = new Float32Array(totalLen);
      let offset = 0;
      for (const chunk of rawBuffers) {
        combined.set(chunk, offset);
        offset += chunk.length;
      }

      // Offline で再加工して WAV Blob を作る
      document.getElementById("recording-info").innerText = "オフラインレンダリング中...（少し時間がかかります）";
      const { wavBlob, renderedBuffer } = await renderOfflineAndMakeWavBlob(combined, audioContext.sampleRate);

      if (!wavBlob) {
        alert("レンダリング失敗しました");
        console.error("renderOfflineAndMakeWavBlob returned null");
        return;
      }

      // window に保存して UI や送信に使う
      window.latestRecordingBlob = wavBlob;

      // Wavesurfer に表示（この WAV はブラウザ互換性の高い PCM WAV）
      if (wavesurfer) wavesurfer.load(URL.createObjectURL(wavBlob));

      // 再生用 AudioBuffer をセット（直接 renderedBuffer を使う）
      currentDecodeBuffer = renderedBuffer;

      document.getElementById("recording-info").innerText = "録音データ取得済み ✓";
      console.log("録音停止 - オフラインレンダリング完了");
    });

    // 再生ボタン（ライブパイプラインを通して再生）
    buttonPlay.addEventListener('click', () => {
      if (!currentDecodeBuffer) {
        console.warn("再生するバッファがありません");
        return;
      }
      playProcessedAudio(currentDecodeBuffer);
    });

    // 保存ボタンは既存のページ側スクリプトと連携（window.latestRecordingBlob を送る）
    // 既に recordings/index.html.erb 側で save の処理が実装されている想定です

    // -------------------
    // --- turbo:before-cache cleanup ---
    // -------------------
    document.addEventListener("turbo:before-cache", () => {
      try { audioContext.close(); } catch (e) {}
      window.__audioInitialized__ = false;
    });

  } catch (err) {
    console.error(err);
  }
});
