import { encodeAudio } from "./encode-audio";

document.addEventListener('turbo:load', async function recording () {
  if (window.__audioInitialized__) return
  window.__audioInitialized__ = true

  try {
    const buttonStart = document.querySelector('#buttonStart')
    const buttonStop = document.querySelector('#buttonStop')
    const buttonSave = document.querySelector('#buttonSave')
    const audio = document.querySelector('#audio')
    const volumeSlider = document.querySelector('#volumeSlider')

    const audioContext = new (window.AudioContext || window.webkitAudioContext)() 
    await audioContext.audioWorklet.addModule('/audio-recorder.js')

    // 再生用ノードのセットアップ
    const playbackGain = audioContext.createGain()
    const playbackSource = audioContext.createMediaElementSource(audio)
    playbackSource.connect(playbackGain).connect(audioContext.destination)

    // 録音準備
    const stream = await navigator.mediaDevices.getUserMedia({
      video: false,
      audio: true,
    })
    const [track] = stream.getAudioTracks()
    const settings = track.getSettings()
    const mediaStreamSource = audioContext.createMediaStreamSource(stream)
    const audioRecorder = new AudioWorkletNode(audioContext, 'audio-recorder')
    const buffers = []

    // 録音データ受信
    audioRecorder.port.onmessage = (event) => {
      let data = event.data
      if (data instanceof ArrayBuffer) {
        data = new Float32Array(data)
      }
      buffers.push(data)
    }
    
    // 録音時はスピーカーに出さない
    mediaStreamSource.connect(audioRecorder)
    
    // 録音開始
    buttonStart.addEventListener('click', async () => {
      await audioContext.resume()
      buttonStart.disabled = true
      buttonStop.disabled = false
      buttonSave.disabled = true
      buffers.splice(0, buffers.length)
      
      const parameter = audioRecorder.parameters.get('isRecording')
      parameter?.setValueAtTime(1, audioContext.currentTime)
    })
    
    // 録音停止
    buttonStop.addEventListener('click', () => {
      buttonStop.disabled = true
      buttonStart.disabled = false
      buttonSave.disabled = false
      
      const parameter = audioRecorder.parameters.get('isRecording')
      parameter?.setValueAtTime(0, audioContext.currentTime)
      
      const blob = encodeAudio(buffers, settings)
      const url = URL.createObjectURL(blob)
      audio.src = url
      audio.play().catch(err => console.warn('再生エラー:', err))
    })
    
    // 再生時の音量調整
    volumeSlider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value)
      playbackGain.gain.setValueAtTime(value, audioContext.currentTime)
    })

    // 保存ボタン
    buttonSave.addEventListener('click', () => {
      // 現在のGain値を反映したデータを生成
      const gainValue = playbackGain.gain.value

      // 各バッファの音量を調整してから保存
      const adjustedBuffers = buffers.map(buf => buf.map(sample => sample * gainValue))
      
      const blob = encodeAudio(adjustedBuffers, settings)
      const url = URL.createObjectURL(blob)

      // ダウンロードリンク生成
      const a = document.createElement('a')
      a.href = url
      a.download = 'recording_with_gain.wav'
      a.click()
  })

  } catch (err) {
    console.error(err)
  }
})
