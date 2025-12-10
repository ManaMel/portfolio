// app/javascript/timing_adjuster.js
class TimingAdjuster {
  constructor({originalUrl, accompUrl, initialDelaySeconds = 0, initialGain = 0.5}) {
    this.originalUrl = originalUrl;
    this.accompUrl = accompUrl;
    this.delaySeconds = initialDelaySeconds;
    this.vocalGain = initialGain;

    this.playButton = document.getElementById("playPreviewButton");
    this.playButtonText = document.getElementById("playButtonText");
    this.delayInput = document.getElementById("delay-slider");
    this.gainInput = document.getElementById("gain-slider");
    this.formElement = document.getElementById("timingAdjustmentForm");
    this.delayDisplay = document.getElementById("delay-value");
    this.gainDisplay = document.getElementById("gain-value");

    if (!this.playButton || !this.delayInput || !this.gainInput || !this.formElement || !this.delayDisplay || !this.gainDisplay) {
      console.error("TimingAdjuster: 必要な要素が見つかりません");
      if (this.playButton) this.setButtonText("初期化エラー");
      return;
    }

    if (!originalUrl || !accompUrl) {
      console.error("TimingAdjuster: 音声URLが指定されていません");
      this.setButtonText("URLエラー");
      return;
    }

    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    this.originalBuffer = null;
    this.accompBuffer = null;
    this.currentSources = [];

    this.setupEventListeners();
    this.loadAudioFiles();
  }

  setButtonText(text) {
    if (this.playButtonText) {
      this.playButtonText.textContent = text;
    } else if (this.playButton) {
      this.playButton.textContent = text;
    }
  }

  async loadAudioFiles() {
    this.playButton.disabled = true;
    this.setButtonText('音声ファイルを読み込み中...');

    try {
      console.log('Loading audio files...', {
        originalUrl: this.originalUrl,
        accompUrl: this.accompUrl
      });

      const [originalResponse, accompResponse] = await Promise.all([
        fetch(this.originalUrl),
        fetch(this.accompUrl)
      ]);

      if (!originalResponse.ok || !accompResponse.ok) {
        throw new Error(`HTTP error! Original: ${originalResponse.status}, Accomp: ${accompResponse.status}`);
      }

      const [originalData, accompData] = await Promise.all([
        originalResponse.arrayBuffer(),
        accompResponse.arrayBuffer()
      ]);

      console.log('Decoding audio data...');
      this.originalBuffer = await this.audioContext.decodeAudioData(originalData);
      this.accompBuffer = await this.audioContext.decodeAudioData(accompData);

      console.log('Audio files loaded successfully', {
        originalDuration: this.originalBuffer.duration,
        accompDuration: this.accompBuffer.duration
      });

      this.playButton.disabled = false;
      this.setButtonText('プレビュー再生');
    } catch (e) {
      console.error("Audio load error:", e);
      this.setButtonText('読み込み失敗');
      this.playButton.disabled = true;
    }
  }

  setupEventListeners() {
    this.playButton.addEventListener('click', () => this.playPreview());

    this.delayInput.addEventListener('input', e => {
      this.delaySeconds = parseFloat(e.target.value);
      this.delayDisplay.textContent = this.delaySeconds.toFixed(2);
      this.stopPlayback();
    });

    this.gainInput.addEventListener('input', e => {
      this.vocalGain = parseFloat(e.target.value);
      this.gainDisplay.textContent = this.vocalGain.toFixed(2);
      this.stopPlayback();
    });

    this.formElement.addEventListener('submit', () => {
      const delayField = this.formElement.querySelector('input[name="recording[recording_delay]"]');
      const gainField = this.formElement.querySelector('input[name="recording[vocal_gain]"]');
      
      if (delayField) delayField.value = this.delaySeconds;
      if (gainField) gainField.value = this.vocalGain;
    });
  }

  stopPlayback() {
    if (this.currentSources.length > 0) {
      this.currentSources.forEach(source => {
        try {
          source.stop();
          source.disconnect();
        } catch (e) {}
      });
      this.currentSources = [];
      this.setButtonText('プレビュー再生');
    }
  }

  playPreview() {
    if (!this.originalBuffer || !this.accompBuffer) {
      console.warn('Audio buffers not loaded yet');
      return;
    }

    if (this.currentSources.length > 0) {
      this.stopPlayback();
      return;
    }

    this.setButtonText('再生中... (クリックで停止)');

    const startTime = this.audioContext.currentTime;

    const originalSource = this.audioContext.createBufferSource();
    originalSource.buffer = this.originalBuffer;
    const originalGain = this.audioContext.createGain();
    originalGain.gain.setValueAtTime(this.vocalGain, startTime);
    originalSource.connect(originalGain).connect(this.audioContext.destination);

    const accompSource = this.audioContext.createBufferSource();
    accompSource.buffer = this.accompBuffer;
    const accompGain = this.audioContext.createGain();
    accompGain.gain.setValueAtTime(1.0 - this.vocalGain, startTime);
    accompSource.connect(accompGain).connect(this.audioContext.destination);

    let originalStartTime = startTime;
    let originalOffset = 0;

    if (this.delaySeconds > 0) {
      originalStartTime += this.delaySeconds;
    } else if (this.delaySeconds < 0) {
      originalOffset = Math.abs(this.delaySeconds);
    }

    accompSource.start(startTime);
    originalSource.start(originalStartTime, originalOffset);

    this.currentSources = [originalSource, accompSource];

    const maxDuration = Math.max(
      this.originalBuffer.duration + Math.max(this.delaySeconds, 0),
      this.accompBuffer.duration
    );

    setTimeout(() => {
      this.stopPlayback();
    }, maxDuration * 1000);
  }
}

// Turbo対応の自動初期化
function initializeTimingAdjuster() {
  // 既に初期化済みの場合はスキップ
  if (window.__timingAdjusterInitialized__) return;
  
  // data-timing-adjuster属性を持つ要素を探す
  const container = document.querySelector('[data-timing-adjuster]');
  if (!container) return;

  const originalUrl = container.dataset.originalUrl;
  const accompUrl = container.dataset.accompUrl;
  const initialDelaySeconds = parseFloat(container.dataset.initialDelay || 0);
  const initialGain = parseFloat(container.dataset.initialGain || 0.5);

  console.log('Initializing TimingAdjuster', {
    originalUrl,
    accompUrl,
    initialDelaySeconds,
    initialGain
  });

  new TimingAdjuster({
    originalUrl,
    accompUrl,
    initialDelaySeconds,
    initialGain
  });
  
  window.__timingAdjusterInitialized__ = true;
}

// Turboイベントで初期化
document.addEventListener('turbo:load', initializeTimingAdjuster);

// Turboキャッシュ前にクリーンアップ
document.addEventListener('turbo:before-cache', () => {
  window.__timingAdjusterInitialized__ = false;
});

// 初回読み込み時
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeTimingAdjuster);
} else {
  initializeTimingAdjuster();
}