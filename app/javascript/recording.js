import { encodeAudio } from "./encode-audio";

document.addEventListener('turbo:load', async function recording() {
  if (window.__audioInitialized__) return;
  window.__audioInitialized__ = true;

  try {
    const buttonStart = document.querySelector('#buttonStart');
    const buttonStop = document.querySelector('#buttonStop');
    const buttonSave = document.querySelector('#buttonSave');
    const buttonPlay = document.querySelector('#buttonPlay');
    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');
    const echoDelaySlider = document.querySelector('#echoDelay');
    const echoFeedbackSlider = document.querySelector("#echoFeedback")

    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    await audioContext.audioWorklet.addModule('/audio-recorder.js');

    // === 全体音量 ===
    const playbackGain = audioContext.createGain();
    playbackGain.gain.value = 1.0;
    playbackGain.connect(audioContext.destination);

    // === リバーブ構成 ===
    const convolver = audioContext.createConvolver();
    const reverbDryGain = audioContext.createGain();
    const reverbWetGain = audioContext.createGain();
    const reverbInput = audioContext.createGain();

    reverbInput.connect(reverbDryGain);
    reverbInput.connect(convolver);
    convolver.connect(reverbWetGain);

    reverbDryGain.connect(playbackGain);
    reverbWetGain.connect(playbackGain);

    // === エコー構成 ===
    const delay = audioContext.createDelay(5.0); // 最大5秒まで遅延可能
    const feedbackGain = audioContext.createGain();
    const echoWetGain = audioContext.createGain();
    const echoDryGain = audioContext.createGain();

    delay.delayTime.value = 0.25; // デフォルト0.25秒
    feedbackGain.gain.value = 0.3;
    echoWetGain.gain.value = 0.5;
    echoDryGain.gain.value = 0.5;

    // エコー配線
    const echoInput = audioContext.createGain();
    echoInput.connect(echoDryGain);
    echoInput.connect(delay);

    delay.connect(feedbackGain);
    feedbackGain.connect(delay); // フィードバックループ

    delay.connect(echoWetGain);

    echoDryGain.connect(reverbInput);
    echoWetGain.connect(reverbInput);

    // === IRファイル読み込み ===
    const irBuffer = await fetch('/1 Halls 01 Large Hall_16bit.wav')
      .then(res => res.arrayBuffer())
      .then(buf => audioContext.decodeAudioData(buf));
    convolver.buffer = irBuffer;
    console.log('IR（リバーブ）読み込み成功');

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
    let activeSource = null;

    // === 再生関数 ===
    function playProcessedAudio(audioBuffer) {
      if (!audioBuffer) return;

      if (activeSource) {
        try {
          activeSource.stop();
        } catch (e) {}
        activeSource.disconnect();
        activeSource = null;
      }

      const source = audioContext.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(echoInput);
      source.start();
      activeSource = source;

      console.log("再生開始（リバーブ＋エコー）");
    }

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

      console.log("録音完了・AudioBuffer準備OK");
      playProcessedAudio(currentDecodeBuffer);
    });

    // === 録音済みを再生 ===
    buttonPlay.addEventListener("click", (e) => {
      playProcessedAudio(currentDecodeBuffer);
    });

    // === 音量スライダー ===
    volumeSlider.addEventListener('input', (e) => {
      playbackGain.gain.setValueAtTime(parseFloat(e.target.value), audioContext.currentTime);
    });

    // === リバーブスライダー ===
    reverbSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      reverbDryGain.gain.setValueAtTime(1 - value, audioContext.currentTime);
      reverbWetGain.gain.setValueAtTime(value, audioContext.currentTime);
    });

    // === エコー遅延スライダー ===
    echoDelaySlider.addEventListener("input", (e) => {
      delay.delayTime.setValueAtTime(parseFloat(e.target.value), audioContext.currentTime);
    });

    // === エコー残響スライダー ===
    echoFeedbackSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      feedbackGain.gain.setValueAtTime(value * 0.9, audioContext.currentTime); // 減衰
      echoWetGain.gain.setValueAtTime(value, audioContext.currentTime);
      echoDryGain.gain.setValueAtTime(1 - value, audioContext.currentTime);
    });

    // === 保存処理 ===
    buttonSave.addEventListener('click', async () => {
      if (!currentDecodeBuffer) return;

      const offlineCtx = new OfflineAudioContext(
        currentDecodeBuffer.numberOfChannels,
        currentDecodeBuffer.length,
        currentDecodeBuffer.sampleRate
      );

      const source = offlineCtx.createBufferSource();
      source.buffer = currentDecodeBuffer;

      // オフライン用に同じ構成を再現
      const conv = offlineCtx.createConvolver();
      conv.buffer = convolver.buffer;

      const delay = offlineCtx.createDelay(5.0);
      const feedback = offlineCtx.createGain();
      const wet = offlineCtx.createGain();
      const dry = offlineCtx.createGain();
      const master = offlineCtx.createGain();

      delay.delayTime.value = parseFloat(echoDelaySlider.value);
      feedback.gain.value = parseFloat(echoFeedbackSlider.value);
      wet.gain.value = parseFloat(echoFeedbackSlider.value);
      dry.gain.value = 1 - parseFloat(echoFeedbackSlider.value);
      master.gain.value = playbackGain.gain.value;

      // エコー配線
      source.connect(dry);
      source.connect(delay);
      delay.connect(feedback);
      feedback.connect(delay);
      delay.connect(wet);

      // リバーブ接続
      const reverbIn = offlineCtx.createGain();
      const reverbDry = offlineCtx.createGain();
      const reverbWet = offlineCtx.createGain();

      wet.connect(reverbIn);
      dry.connect(reverbIn);

      reverbIn.connect(reverbDry);
      reverbIn.connect(conv);
      conv.connect(reverbWet);

      reverbDry.connect(master);
      reverbWet.connect(master);
      master.connect(offlineCtx.destination);

      source.start();

      const rendered = await offlineCtx.startRendering();

      const out = [];
      for (let ch = 0; ch < rendered.numberOfChannels; ch++) {
        out.push(Float32Array.from(rendered.getChannelData(ch)));
      }

      const blob = encodeAudio(out, { sampleRate: rendered.sampleRate });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'recording_reverb_echo.wav';
      a.click();

      console.log("保存完了（リバーブ＋エコー適用済）");
    });

  } catch (err) {
    console.error(err);
  }
});
