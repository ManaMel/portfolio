class Recording < ApplicationRecord
  belongs_to :user
  has_many :videos, dependent: :destroy

  # Active Storage 用の添付
  has_one_attached :original_audio # Audio_pathではなく別名に変更
  has_one_attached :accompaniment
  has_one_attached :generated_audio

  validates :title, length: { maximum: 255 }
end
