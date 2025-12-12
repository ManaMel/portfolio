class VideoGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :recording

  has_one_attached :thumbnail_image
  has_one_attached :generated_video

  enum status: {
    created: 0,
    ready: 1,
    generating: 2,
    generated: 3,
    failed: 4,
    uploading: 5,
    uploaded: 6
  }

  enum upload_destination: {
    user_channel: 0,
    app_channel: 1
  }

  validates :title, presence: true
  validates :body, length: { maximum: 1000 }, allow_blank: true

  def ready_for_generation?
    recording&.generated_audio&.attached? && thumbnail_image.attached?
  end

  def ready_for_youtube_upload?
    generated? && generated_video.attached?
  end

  def can_upload_to_user_channel?
    user.youtube_authenticated?
  end
end
