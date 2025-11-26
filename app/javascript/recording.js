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

    // --- グローバル再生パイプライン ---
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
    let currentDecodeBuffer = null;
    let activeSource = null;

    function playProcessedAudio(bufferToPlay) {
      if (!bufferToPlay) return;
      if (activeSource) {
        try { activeSource.stop(); } catch {}
        try { activeSource.disconnect(); } catch {}
      }
      const source = audioContext.createBufferSource();
      source.buffer = bufferToPlay;
      source.connect(echoInput);
      source.start();
      activeSource = source;
    }

    function audioBufferToWavBlob(audioBuffer) {
      const out = [];
      for (let ch = 0; ch < audioBuffer.numberOfChannels; ch++) {
        out.push(Float32Array.from(audioBuffer.getChannelData(ch)));
      }
      return encodeAudio(out, { sampleRate: audioBuffer.sampleRate });
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
      
      const totalLen = buffers.reduce((s, b) => s + b.length, 0);
      const outBuf = audioContext.createBuffer(1, totalLen, audioContext.sampleRate);
      const channel = outBuf.getChannelData(0);
      let offset = 0;
      for (const chunk of buffers) {
        channel.set(chunk, offset);
        offset += chunk.length;
      }
      currentDecodeBuffer = outBuf;
      
      if (wavesurfer) {
        const blob = encodeAudio([Float32Array.from(currentDecodeBuffer.getChannelData(0))], { sampleRate: currentDecodeBuffer.sampleRate });
        wavesurfer.load(URL.createObjectURL(blob));
      }

      // WAV化して window に保存
      window.latestRecordingBlob = audioBufferToWavBlob(currentDecodeBuffer);

      // UI 更新
      document.getElementById("recording-info").innerText = "録音データ取得済み ✓";
      document.getElementById("save-recording-btn").disabled = false;
      console.log("録音停止");
    });

    buttonPlay.addEventListener('click', () => playProcessedAudio(currentDecodeBuffer));

    

    // --- スライダー --- 
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

    // --- Turbo cleanup ---
    document.addEventListener("turbo:before-cache", () => {
      try { audioContext.close(); } catch {}
      window.__audioInitialized__ = false;
    });

  } catch (err) {
    console.error(err);
  }
});
