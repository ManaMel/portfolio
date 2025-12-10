class ChangeRecordingDelayToDecimal < ActiveRecord::Migration[7.2]
  def change
    change_column :recordings, :recording_delay, :decimal, precision: 8, scale: 2
    change_column :recordings, :vocal_gain, :decimal, precision: 5, scale: 2
  end
end
