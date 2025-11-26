// audio-recorder.js
class AudioRecorderProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [{ name: 'isRecording', defaultValue: 0 }];
  }

  constructor() {
    super();
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];

    // どちらにデータが入っているか確認（モノラル/ステレオ対応）
    const channelData = input && (input[0] || input[1]);
    if (!channelData) return true;

    const isRecording = parameters.isRecording[0] === 1;

    if (isRecording) {
      // Float32Array をコピーして ArrayBuffer にして送信
      const copy = new Float32Array(channelData);
      this.port.postMessage(copy.buffer, [copy.buffer]);
    }

    return true;
  }
}

registerProcessor('audio-recorder', AudioRecorderProcessor);
