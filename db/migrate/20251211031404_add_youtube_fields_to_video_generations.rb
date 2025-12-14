class AddYoutubeFieldsToVideoGenerations < ActiveRecord::Migration[7.2]
  def change
    add_column :video_generations, :youtube_url, :string
    add_column :video_generations, :youtube_video_id, :string
    add_column :video_generations, :uploaded_to_youtube, :boolean, default: false
    add_column :video_generations, :upload_destination, :integer, default: 0
  end
end
