class VideoGeneration < ApplicationRecord
  belongs_to :recording
  has_one_attached :video_file
end
