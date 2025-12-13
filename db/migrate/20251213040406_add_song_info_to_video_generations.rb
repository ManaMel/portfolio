class AddSongInfoToVideoGenerations < ActiveRecord::Migration[7.2]
  def change
    add_column :video_generations, :song_title, :string
    add_column :video_generations, :original_artist, :string
    add_column :video_generations, :composer, :string
    add_column :video_generations, :lyricist, :string
    add_column :video_generations, :copyright_notes, :text
  end
end
