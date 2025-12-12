class YoutubeUploadJob < ApplicationJob
  queue_as :default
  
  def perform(video_generation_id)
    video_gen = VideoGeneration.find(video_generation_id)
    
    Rails.logger.info "YoutubeUploadJob: Start uploading video ##{video_generation_id}"
    
    # アップロード準備ができているかチェック
    unless video_gen.ready_for_youtube_upload?
      raise "Video not ready for upload"
    end
    
    # ステータスを「アップロード中」に変更
    video_gen.update!(status: :uploading)
    
    # アップロード実行
    uploader = YoutubeUploader.new(video_gen)
    youtube_url = uploader.upload!
    
    Rails.logger.info "YoutubeUploadJob: Successfully uploaded to #{youtube_url}"
    
  rescue => e
    # エラーが起きたら記録
    Rails.logger.error "YoutubeUploadJob Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    video_gen.update!(status: :failed, error_message: e.message)
  end
end
