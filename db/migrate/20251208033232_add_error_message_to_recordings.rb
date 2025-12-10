class AddErrorMessageToRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :recordings, :error_message, :text
  end
end
