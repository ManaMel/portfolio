class AddRecordingDelayToRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :recordings, :recording_delay, :integer, default: 0, null: false
  end
end
