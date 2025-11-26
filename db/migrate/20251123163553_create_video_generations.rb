class CreateVideoGenerations < ActiveRecord::Migration[7.2]
  def change
    create_table :video_generations do |t|
      t.references :user, foreign_key: true
      t.references :recording, foreign_key: true
      t.references :video, foreign_key: true
      t.string :title
      t.text :body
      t.string :video_url

      t.timestamps
    end
  end
end
