import { encodeAudio } from "./encode-audio";

document.addEventListener('turbo:load', async function recording() {
  if (window.__audioInitialized__) return;
  window.__audioInitialized__ = true;

  try {
    const buttonStart = document.querySelector('#buttonStart');
    const buttonStop = document.querySelector('#buttonStop');
    const buttonSave = document.querySelector('#buttonSave');
    const buttonReplay = document.querySelector('#buttonReplay'); // 再生ボタンをHTMLに作る
    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');

    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    await audioContext.audioWorklet.addModule('/audio-recorder.js');

    // === 再生音量全体 ===
    const playbackGain = audioContext.createGain();
    playbackGain.gain.value = 1.0;
    playbackGain.connect(audioContext.destination);

    // === リバーブ構成 ===
    const convolver = audioContext.createConvolver();
    const wetGain = audioContext.createGain();
    const dryGain = audioContext.createGain();
    const reverbInput = audioContext.createGain();

    reverbInput.connect(dryGain);
    reverbInput.connect(convolver);
    convolver.connect(wetGain);

    dryGain.connect(playbackGain);
    wetGain.connect(playbackGain);

    dryGain.gain.value = 1.0;
    wetGain.gain.value = 0.0;

    // === IRファイル読み込み ===
    const irBuffer = await fetch('/1 Halls 01 Large Hall_16bit.wav')
      .then(res => res.arrayBuffer())
      .then(buf => audioContext.decodeAudioData(buf));
    convolver.buffer = irBuffer;
    console.log('✅ IR読み込み成功');

    // === 録音準備 ===
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const [track] = stream.getAudioTracks();
    const settings = track.getSettings();
    const mediaStreamSource = audioContext.createMediaStreamSource(stream);
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder');
    const buffers = [];

    mediaStreamSource.connect(audioRecorder);

    audioRecorder.port.onmessage = (event) => {
      let data = event.data;
      if (data instanceof ArrayBuffer) data = new Float32Array(data);
      buffers.push(data);
    };

    let currentDecodeBuffer = null;

    // === 再生関数 ===
    function playWithReverb(audioBuffer) {
      const source = audioContext.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(reverbInput);
      source.start();
      return source;
    }

    let activeSource = null;

    // === 録音開始 ===
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume();
      buttonStart.disabled = true;
      buttonStop.disabled = false;
      buttonSave.disabled = true;
      buffers.splice(0, buffers.length);

      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(1, audioContext.currentTime);
    });

    // === 録音停止 ===
    buttonStop.addEventListener('click', async () => {
      buttonStop.disabled = true;
      buttonStart.disabled = false;
      buttonSave.disabled = false;

      const param = audioRecorder.parameters.get('isRecording');
      param?.setValueAtTime(0, audioContext.currentTime);

      const blob = encodeAudio(buffers, settings);
      const arrayBuffer = await blob.arrayBuffer();
      currentDecodeBuffer = await audioContext.decodeAudioData(arrayBuffer);

      console.log("🎧 録音完了・AudioBuffer準備OK");

      // 初回自動再生
      if (activeSource) activeSource.stop();
      activeSource = playWithReverb(currentDecodeBuffer);
    });

    // === 再生ボタン ===
    if (buttonReplay) {
      buttonReplay.addEventListener('click', () => {
        if (!currentDecodeBuffer) return;
        if (activeSource) {
          try { activeSource.stop(); } catch(e) {}
        }
        activeSource = playWithReverb(currentDecodeBuffer);
      });
    }

    // === 音量スライダー ===
    volumeSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      playbackGain.gain.setValueAtTime(value, audioContext.currentTime);
    });

    // === リバーブスライダー ===
    reverbSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      dryGain.gain.setValueAtTime(1 - value, audioContext.currentTime);
      wetGain.gain.setValueAtTime(value, audioContext.currentTime);
    });

    // === 保存処理 ===
    buttonSave.addEventListener('click', async () => {
      if (!currentDecodeBuffer || !convolver.buffer) return;

      const gainValue = playbackGain.gain.value;
      const wetValue = wetGain.gain.value;
      const dryValue = dryGain.gain.value;

      const offlineCtx = new OfflineAudioContext(
        currentDecodeBuffer.numberOfChannels,
        currentDecodeBuffer.length,
        currentDecodeBuffer.sampleRate
      );

      const source = offlineCtx.createBufferSource();
      source.buffer = currentDecodeBuffer;

      const conv = offlineCtx.createConvolver();
      conv.buffer = convolver.buffer;

      const dry = offlineCtx.createGain();
      const wet = offlineCtx.createGain();
      const outMaster = offlineCtx.createGain();

      dry.gain.value = dryValue * gainValue;
      wet.gain.value = wetValue * gainValue;

      source.connect(dry);
      source.connect(conv);
      conv.connect(wet);

      dry.connect(outMaster);
      wet.connect(outMaster);
      outMaster.connect(offlineCtx.destination);

      source.start();

      const renderedBuffer = await offlineCtx.startRendering();

      const outChannels = [];
      for (let ch = 0; ch < renderedBuffer.numberOfChannels; ch++) {
        outChannels.push(Float32Array.from(renderedBuffer.getChannelData(ch)));
      }

      const blob = encodeAudio(outChannels, { sampleRate: renderedBuffer.sampleRate });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'recording_with_reverb.wav';
      a.click();

      console.log("💾 保存完了");
    });

  } catch (err) {
    console.error(err);
  }
});
