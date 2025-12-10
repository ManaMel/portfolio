class ChangeRecordingIdNullableInVideos < ActiveRecord::Migration[7.2]
  def change
    change_column_null :videos, :recording_id, true
  end
end
