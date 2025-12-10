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
    failed: 4
  }

  validates :title, presence: true
  validates :body, length: { maximum: 1000 }, allow_blank: true

  def ready_for_generation?
    recording&.generated_audio&.attached? && thumbnail_image.attached?
  end
end
