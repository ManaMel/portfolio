class GainProcessor extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [
      { name: 'gain', defaultValue: 1, minValue: 0, maxValue: 2 }
    ]
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0]
    const output = outputs[0]
    const gain = parameters.gain

    if (input.length > 0) {
      const inputChannel = input[0]
      const outputChannel = output[0]

      for (let i = 0; i < inputChannel.length; i++) {
        // gain が変化している場合にも対応
        const g = gain.length > 1 ? gain[i] : gain[0]
        outputChannel[i] = inputChannel[i] * g
      }
    }

    return true
  }
}

registerProcessor('gain-processor', GainProcessor)
