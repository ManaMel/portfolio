class Profile < ApplicationRecord
  belongs_to :user
  has_one_attached :avatar # 画像アップロード
  validates :name, length: { maximum: 50 }
  validates :musical_carrer, length: { maximum: 255 }
end
