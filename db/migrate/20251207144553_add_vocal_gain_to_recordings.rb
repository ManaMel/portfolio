class AddVocalGainToRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :recordings, :vocal_gain, :float, default: 1.0
  end
end
