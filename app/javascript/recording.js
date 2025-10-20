import { encodeAudio } from "./encode-audio";

document.addEventListener('turbo:load', async function recording () {
  if (window.__audioInitialized__) return;
  window.__audioInitialized__ = true;

  try {
    const buttonStart = document.querySelector('#buttonStart');
    const buttonStop = document.querySelector('#buttonStop');
    const buttonSave = document.querySelector('#buttonSave');
    const audio = document.querySelector('#audio');
    const volumeSlider = document.querySelector('#volumeSlider');
    const reverbSlider = document.querySelector('#reverbSlider');

    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    await audioContext.audioWorklet.addModule('/audio-recorder.js');

    // 再生用ノードのセットアップ
    const playbackGain = audioContext.createGain();
    const playbackSource = audioContext.createMediaElementSource(audio);
    playbackSource.connect(playbackGain).connect(audioContext.destination);

    // リバーブノード
    const convolver = audioContext.createConvolver();
    const wetGain = audioContext.createGain();
    const dryGain = audioContext.createGain();

    // リバーブ音データ(インパルス応答)を読み込みfetch('/AK-SROOMS__018.wav')
    fetch('/1 Halls 01 Large Hall_16bit.wav')
      .then(response => {
        console.log('response ok?', response.ok);
        console.log('content-type:', response.headers.get('content-type'));
        return response.arrayBuffer();
      })
      .then(arrayBuffer => {
        console.log('arrayBuffer type:', arrayBuffer.constructor.name);
        return audioContext.decodeAudioData(arrayBuffer);
      })
      .then(audioBuffer => {
        convolver.buffer = audioBuffer;
        console.log('✅ リバーブIR読み込み成功');
      })
      .catch(error => console.error('❌ IR読み込みエラー:', error));

    // fetch('/AK-SROOMS__018.wav')
    //     .then(response => response.arrayBuffer())
    //     .then(arrayBuffer => audioContext.decodeAudioData(arrayBuffer))
    //     .then(audioBuffer => {
    //         convolver.buffer = audioBuffer
    //     });

    // 録音準備
    const stream = await navigator.mediaDevices.getUserMedia({
      video: false,
      audio: true,
    });
    const [track] = stream.getAudioTracks();
    const settings = track.getSettings();
    const mediaStreamSource = audioContext.createMediaStreamSource(stream);
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder');
    const buffers = [];

    // 録音データ受信
    audioRecorder.port.onmessage = (event) => {
      let data = event.data;
      if (data instanceof ArrayBuffer) {
        data = new Float32Array(data);
      }
      buffers.push(data);
    };
    
    // 録音時はスピーカーに出さない
    mediaStreamSource.connect(audioRecorder);
    
    // 録音開始
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume();
      buttonStart.disabled = true;
      buttonStop.disabled = false;
      buttonSave.disabled = true;
      buffers.splice(0, buffers.length);
      
      const parameter = audioRecorder.parameters.get('isRecording');
      parameter?.setValueAtTime(1, audioContext.currentTime);
    });

    // 再生時にリバーブ調整できるようにする
    let currentDecodeBuffer = null;

    // 録音停止
    buttonStop.addEventListener('click', async () => {
      buttonStop.disabled = true;
      buttonStart.disabled = false;
      buttonSave.disabled = false;
      
      const parameter = audioRecorder.parameters.get('isRecording');
      parameter?.setValueAtTime(0, audioContext.currentTime);
      
      // 録音データをデコード
      const blob = encodeAudio(buffers, settings);

      // Audio playerで再生できるようにURLを設定
      const url = URL.createObjectURL(blob);
      audio.src = url;

      // AudioBufferとしても保持しておく(リバーブ用)
      const arrayBuffer = await blob.arrayBuffer();
      currentDecodeBuffer = await audioContext.decodeAudioData(arrayBuffer);

      console.log("録音完了・Audioタグ再生OK・AudioBuffer準備完了");

      // audio playerを自動再生(ブラウザの設定によっては手動クリックが必要)
      playWithReverb(currentDecodeBuffer);
      audio.play();
      
    });
    
    // 音量スライダー
    volumeSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      playbackGain.gain.setValueAtTime(value, audioContext.currentTime);
    });

    // リバーブスライダー
    reverbSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value);
      dryGain.gain.setValueAtTime(1 - value, audioContext.currentTime);
      wetGain.gain.setValueAtTime(value * 2, audioContext.currentTime);
    });
    
    // 再生関数(リバーブ付き)
    function playWithReverb(audioBuffer) {
      const source = audioContext.createBufferSource();
      source.buffer = audioBuffer;

      // 接続し直すたびにリバーブ構造を構築
      source.connect(dryGain);
      source.connect(convolver);
      convolver.connect(wetGain);

      dryGain.connect(audioContext.destination);
      wetGain.connect(audioContext.destination);

      source.start();
    }

    // 保存ボタン
    buttonSave.addEventListener('click', () => {
      if (!currentDecodeBuffer) return;

      // 現在のGain値を反映したデータを生成
      const gainValue = playbackGain.gain.value;
      const reverbValue = wetGain.gain.value;

      // 各バッファをgainとreverbに合わせて調整
      const dryLevel = 1 - reverbValue;
      const wetLevel = reverbValue;

      // 録音した音声に対してリバーブを適用
      const offlineCtx = new OfflineAudioContext(
        1,
        currentDecodeBuffer.length,
        currentDecodeBuffer.sampleRate
      );

      const source = offlineCtx.createBufferSource();
      source.buffer = currentDecodeBuffer;

      const conv = offlineCtx.createConvolver();
      conv.buffer = convolver.buffer;

      const dry = offlineCtx.createGain();
      const wet = offlineCtx.createGain();

      dry.gain.value = dryLevel * gainValue;
      wet.gain.value = wetLevel * gainValue;

      source.connect(dry);
      source.connect(conv);
      conv.connect(wet);
      dry.connect(offlineCtx.destination);
      wet.connect(offlineCtx.destination);

      source.start();

      // オフラインで合成してから書き出し
      offlineCtx.startRecording().then(renderedBuffer => {
        const renderedData = renderedBuffer.getChannelData(0);
        const adjustedBuffers = [Float32Array.from(renderedData)];
        const blob = encodeAudio(adjustedBuffers, settings);
        
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        // ダウンロードリンク生成
        a.href = url;
        a.download = 'recording_with_gain.wav';
        a.click();
      });
  });

  } catch (err) {
    console.error(err);
  }
});
