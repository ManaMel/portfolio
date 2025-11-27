class Video < ApplicationRecord
  validates :title, length: { maximum: 255 }
  validates :body, length: { maximum: 65_535 }

  belongs_to :user
  belongs_to :recording, optional: true
end
