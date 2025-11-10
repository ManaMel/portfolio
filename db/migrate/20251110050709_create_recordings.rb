class CreateRecordings < ActiveRecord::Migration[7.2]
  def change
    create_table :recordings do |t|
      t.string :title
      t.string :audio_path
      t.references :user, foreign_key: true
      
      t.timestamps
    end
  end
end
