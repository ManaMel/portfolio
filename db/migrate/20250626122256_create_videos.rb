class CreateVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :videos do |t|
      t.string :title
      t.text :body
      t.string :video_url
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
