class Recording < ApplicationRecord
  enum status: { created: 0, generating: 1, generated: 2, failed: 3 }

  belongs_to :user
  has_many :videos, dependent: :destroy
  has_many :video_generations, dependent: :destroy

  has_one_attached :original_audio
  has_one_attached :accompaniment
  has_one_attached :generated_audio

  after_create :normalize_audio_mime_type

  validates :title, presence: true, length: { maximum: 255 }
  validates :original_audio, presence: true, on: :create

  validates :recording_delay, numericality: true, allow_nil: true
  validates :vocal_gain, numericality: true, allow_nil: true

  def ready_for_generation?
    original_audio.attached? && accompaniment.attached?
  end

  def mixed?
    generated? && generated_audio.attached?
  end

  def start_generation!
    return false unless ready_for_generation?

    update!(status: :generating)
    true
  end

  def mark_generated!
    update!(status: :generated)
  end

  def mark_failed!(log_message = nil)
    if self.has_attribute?(:generation_log)
      update!(status: :failed, generation_log: log_message)
    else
      update!(status: :failed, error_message: log_message)
    end
  end

  private

  def normalize_audio_mime_type
    return unless original_audio.attached?

    current_mime_type = original_audio.content_type
    if current_mime_type.include?("wav") && current_mime_type != "audio/wav"
      original_audio.blob.update!(content_type: "audio/wav")
      Rails.logger.info "Recording #{id}: original_audio MIME type updated from '#{current_mime_type}' to 'audio/wav'."
    end
  end
end
