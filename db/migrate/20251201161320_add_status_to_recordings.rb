class AddStatusToRecordings < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:recordings, :status)
      add_column :recordings, :status, :integer, default: 0, null: false
    end
  end
end
