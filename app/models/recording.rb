class Recording < ApplicationRecord
  enum status: { created: 0, generating: 1, generated: 2 }

  belongs_to :user
  has_many :videos, dependent: :destroy

  # Active Storage 用の添付
  has_one_attached :original_audio # Audio_pathではなく別名に変更
  has_one_attached :accompaniment
  has_one_attached :generated_audio

  validates :title, length: { maximum: 255 }

   # ジョブをキューに入れるとき
  def start_generation!
    update!(status: :generating)
    AudioMixingJob.perform_later(self.id)
  end

   # ジョブ完了時
  def mark_generated!
    update!(status: :generated)
  end
end
