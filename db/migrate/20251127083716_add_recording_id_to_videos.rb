class AddRecordingIdToVideos < ActiveRecord::Migration[7.2]
  def change
    add_reference :videos, :recording, null: false, foreign_key: true
  end
end
