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
    const buttonSave  = document.querySelector('#save-recording-btn');
    const buttonPlay  = document.querySelector('#buttonPlay');
    const waveformContainer = document.querySelector('#waveform');

    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');
    const echoDelaySlider = document.querySelector('#echoDelay');
    const echoFeedbackSlider = document.querySelector('#echoFeedback');

    if (!buttonStart || !buttonStop || !buttonSave || !buttonPlay) return;

    // --- AudioContext & Worklet ---
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    await audioContext.audioWorklet.addModule('/audio-recorder.js');

    // --- WaveSurfer 初期化 ---
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

    // --- グローバル再生パイプライン（リアルタイム再生用） ---
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

    echoInput.connect(echoDryGain);
    echoInput.connect(delayNode);
    delayNode.connect(feedbackGain);
    feedbackGain.connect(delayNode);
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

    // --- IR 読み込み（リバーブ用） ---
    let irBuffer = null;
    try {
      const buf = await fetch('/1 Halls 01 Large Hall_16bit.wav').then(r => r.arrayBuffer());
      irBuffer = await audioContext.decodeAudioData(buf);
      convolver.buffer = irBuffer;
      console.log('IR 読み込み成功');
    } catch (err) {
      console.warn('IR 読み込み失敗', err);
    }

    // --- 録音準備 ---
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mediaStreamSource = audioContext.createMediaStreamSource(stream);
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder');

    const buffers = [];
    audioRecorder.port.onmessage = (event) => {
      let data = event.data;
      if (data instanceof ArrayBuffer) data = new Float32Array(data);
      buffers.push(data);
    };
    mediaStreamSource.connect(audioRecorder);

    // --- 録音バッファ ---
    let rawAudioBuffer = null;      // 生録音データ
    let processedAudioBuffer = null; // エフェクト適用済みバッファ
    let activeSource = null;

    function playProcessedAudio() {
      if (!processedAudioBuffer) return;
      if (activeSource) {
        try { activeSource.stop(); } catch {}
        try { activeSource.disconnect(); } catch {}
      }
      const source = audioContext.createBufferSource();
      source.buffer = processedAudioBuffer;
      source.connect(playbackGain);
      source.start();
      activeSource = source;
    }

    function audioBufferToWavBlob(buffer) {
      const out = [];
      for (let ch = 0; ch < buffer.numberOfChannels; ch++) {
        out.push(Float32Array.from(buffer.getChannelData(ch)));
      }
      return encodeAudio(out, { sampleRate: buffer.sampleRate });
    }

    // --- エフェクト適用 ---
    async function renderProcessedBuffer() {
      if (!rawAudioBuffer) return;
      const offlineCtx = new OfflineAudioContext(1, rawAudioBuffer.length, audioContext.sampleRate);
      const source = offlineCtx.createBufferSource();
      source.buffer = rawAudioBuffer;

      // エフェクトノード
      const gainNode = offlineCtx.createGain();
      gainNode.gain.value = volumeSlider.value;

      const conv = offlineCtx.createConvolver();
      conv.buffer = convolver.buffer;

      const revDry = offlineCtx.createGain();
      const revWet = offlineCtx.createGain();
      revWet.gain.value = reverbSlider.value;
      revDry.gain.value = 1 - reverbSlider.value;

      const del = offlineCtx.createDelay(5.0);
      del.delayTime.value = echoDelaySlider.value;
      const fb = offlineCtx.createGain();
      fb.gain.value = echoFeedbackSlider.value * 0.9;
      const wet = offlineCtx.createGain();
      wet.gain.value = echoFeedbackSlider.value;
      const dry = offlineCtx.createGain();
      dry.gain.value = 1 - echoFeedbackSlider.value;

      source.connect(gainNode);
      gainNode.connect(dry);
      gainNode.connect(del);
      del.connect(fb);
      fb.connect(del);
      del.connect(wet);
      dry.connect(revDry);
      wet.connect(revDry);
      revDry.connect(conv);
      conv.connect(revWet);
      revDry.connect(offlineCtx.destination);
      revWet.connect(offlineCtx.destination);

      source.start();
      processedAudioBuffer = await offlineCtx.startRendering();

      // WAV化して window に保存
      window.latestRecordingBlob = audioBufferToWavBlob(processedAudioBuffer);

      // WaveSurfer にも表示
      if (wavesurfer) {
        wavesurfer.load(URL.createObjectURL(window.latestRecordingBlob));
      }
    }

    // --- イベントハンドラ ---
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume();
      buttonStart.disabled = true;
      buttonStop.disabled = false;
      buttonSave.disabled = true;
      buffers.splice(0, buffers.length);
      if (wavesurfer) wavesurfer.empty();
      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(1, audioContext.currentTime);
      console.log('録音開始');
    });

    buttonStop.addEventListener('click', async () => {
      buttonStop.disabled = true;
      buttonStart.disabled = false;
      buttonSave.disabled = false;

      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(0, audioContext.currentTime);

      if (buffers.length === 0) {
        alert("録音データがありません");
        return;
      }

      // 生録音データを作成
      const totalLen = buffers.reduce((s, b) => s + b.length, 0);
      const outBuf = audioContext.createBuffer(1, totalLen, audioContext.sampleRate);
      const channel = outBuf.getChannelData(0);
      let offset = 0;
      for (const chunk of buffers) {
        channel.set(chunk, offset);
        offset += chunk.length;
      }
      rawAudioBuffer = outBuf;

      // 初回レンダリング（スライダーの初期値を反映）
      await renderProcessedBuffer();

      document.getElementById("recording-info").innerText = "録音データ取得済み ✓";
      console.log("録音停止");
    });

    buttonPlay.addEventListener('click', () => playProcessedAudio());

    // --- スライダーでリアルタイム調整（録音後のみ反映） ---
    [volumeSlider, reverbSlider, echoDelaySlider, echoFeedbackSlider].forEach(slider => {
      slider.addEventListener('input', async () => {
        if (!rawAudioBuffer) return;
        await renderProcessedBuffer();
      });
    });

    // --- Turbo cleanup ---
    document.addEventListener("turbo:before-cache", () => {
      try { audioContext.close(); } catch {}
      window.__audioInitialized__ = false;
    });

  } catch (err) {
    console.error(err);
  }
});
