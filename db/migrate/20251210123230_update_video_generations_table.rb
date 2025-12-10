class UpdateVideoGenerationsTable < ActiveRecord::Migration[7.2]
  def change
    add_column :video_generations, :status, :integer, default: 0, null: false
    add_column :video_generations, :error_message, :text
    
    # 不要なカラムを削除（Active Storageで管理するため）
    remove_column :video_generations, :video_id, :bigint
    remove_column :video_generations, :video_url, :string
  end
end
