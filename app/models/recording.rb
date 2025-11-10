class Recording < ApplicationRecordvalidates 
  validates :title, length: { maximum: 255 }
  validates :audio_path, length: { maximum: 255 }

  has_many :videos, dependent: :destroy

  belongs_to :user
end
