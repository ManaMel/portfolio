class AudioRecorderProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.isRecording = false;
  }

  static get parameterDescriptors() {
    return [];
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];

    if (!this.isRecording) return true;

    // モノラル対応
    const channel = input[0];
    if (!channel) return true;

    let buffer = new Float32Array(channel);
    this.port.postMessage(buffer);

    return true;
  }
}

registerProcessor("audio-recorder-processor", AudioRecorderProcessor);
