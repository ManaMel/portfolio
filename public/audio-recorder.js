// audio-recorder.js
class AudioRecorderProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [{ name: 'isRecording', defaultValue: 0 }]
  }

  constructor() {
    super()
    this._buffer = []
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0]
    if (input && parameters.isRecording[0] === 1) {
      this.port.postMessage(input[0]) // 録音データ送信
    }
    return true
  }
}

registerProcessor('audio-recorder', AudioRecorderProcessor)

// class AudioRecorder extends AudioWorkletProcessor {
//   static get parameterDescriptors() {
//     return [
//       { name: 'isRecording', defaultValue: 0, minValue: 0, maxValue: 1 },
//       { name: 'gain', defaultValue: 1.0, minValue: 0.0, maxValue: 2.0 },
//     ]
//   }

//   process(inputs, outputs, parameters) {
//     const input = inputs[0]
//     if (!input || input.length === 0) return true

//     const channel = 0
//     const isRecording = parameters.isRecording[0]
//     const gain = parameters.gain[0]

//     if (isRecording) {
//       const buffer = new Float32Array(input[channel].length)
//       for (let i = 0; i < input[channel].length; i++) {
//         buffer[i] = input[channel][i] * gain
//       }
//       this.port.postMessage(buffer)
//     }

//     return true
//   }
// }

// registerProcessor('audio-recorder', AudioRecorder)
