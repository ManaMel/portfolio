class Recording < ApplicationRecord
  belongs_to :user
  has_many :videos, dependent: :destroy

  # Active Storage 用の添付
  has_one_attached :audio_file # Audio_pathではなく別名に変更
 
  validates :title, length: { maximum: 255 }
end
