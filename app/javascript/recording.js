import { encodeAudio } from "./encode-audio";

document.addEventListener('turbo:load', async function recording () {
  if (window.__audioInitialized__) return
  window.__audioInitialized__ = true

  try {
    const buttonStart = document.querySelector('#buttonStart')
    const buttonStop = document.querySelector('#buttonStop')
    const audio = document.querySelector('#audio')
    const volumeSlider = document.querySelector('#volumeSlider')

    const audioContext = new (window.AudioContext || window.webkitAudioContext)() 
    await audioContext.audioWorklet.addModule('/audio-recorder.js')

    // 再生用GainNodeを作成
    const playbackGain = audioContext.createGain()

    // AudioElementSourceは一度だけ生成
    if (!audio.__mediaSource__) {
      audio.__mediaSource__ = audioContext.createMediaElementSource(audio)
      audio.__mediaSource__.connect(playbackGain).connect(audioContext.destination)
    }

    // スライダーで音量調整
    volumeSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value)
      playbackGain.gain.setValueAtTime(value, audioContext.currentTime)
    })

    // 録音準備
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    const [track] = stream.getAudioTracks()
    const settings = track.getSettings()

    const mediaStreamSource = audioContext.createMediaStreamSource(stream)
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder')
    const buffers = []

    audioRecorder.port.onmessage = (event) => {
      let data = event.data
      if (data instanceof ArrayBuffer) data = new Float32Array(data)
      buffers.push(data)
    }

    // 録音時はスピーカーに出さない
    mediaStreamSource.connect(audioRecorder)

    // 録音開始
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume()
      buttonStart.disabled = true
      buttonStop.disabled = false
      buffers.splice(0, buffers.length)

      const parameter = audioRecorder.parameters.get('isRecording')
      parameter?.setValueAtTime(1, audioContext.currentTime)
    })

    // 録音停止
    buttonStop.addEventListener('click', () => {
      buttonStop.disabled = true
      buttonStart.disabled = false

      const parameter = audioRecorder.parameters.get('isRecording')
      parameter?.setValueAtTime(0, audioContext.currentTime)

      const blob = encodeAudio(buffers, settings)
      const url = URL.createObjectURL(blob)
      audio.src = url
      audio.play().catch(err => console.warn('再生エラー:', err))
    })

  } catch (err) {
    console.error(err)
  }
})


// document.addEventListener('turbo:load', () => {
//   const record = document.querySelector("#buttonRecord");
//   const stop = document.querySelector("#buttonStop");
//   const audio = document.querySelector("#player");

//   if (!record || !stop || !audio) {
//     console.log("録音用要素が存在しないため、スクリプトをスキップします。");
//     return;
//   }

//   let mediaRecorder;
//   let chunks = [];

//   record.onclick = () => {
//     navigator.mediaDevices.getUserMedia({ audio: true })
//       .then((stream) => {
//         mediaRecorder = new MediaRecorder(stream);
//         chunks = [];

//         mediaRecorder.ondataavailable = (e) => {
//           chunks.push(e.data);
//         };

//         mediaRecorder.onstop = () => {
//           const blob = new Blob(chunks, { type: "audio/webm; codecs=opus" });
//           const audioURL = URL.createObjectURL(blob);
//           audio.src = audioURL;
//         };

//         mediaRecorder.start();
//         console.log("録音開始");

//         record.disabled = true;
//         stop.disabled = false;

//         stop.onclick = () => {
//           mediaRecorder.stop();
//           console.log("録音停止");
//           record.disabled = false;
//           stop.disabled = true;
//         };
//       })
//       .catch((err) => {
//         console.error("マイク取得エラー:", err);
//       });
//   };
// });
