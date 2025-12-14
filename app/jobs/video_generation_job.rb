require 'tempfile'

class VideoGenerationJob < ApplicationJob
  queue_as :default

  def perform(video_generation_id)
    video_gen = VideoGeneration.find(video_generation_id)

    Rails.logger.info "VideoGenerationJob: Start generating video ##{video_generation_id}"

    if video_gen.generated?
      Rails.logger.info "VideoGenerationJob: Already generated, skipping"
      return
    end

    begin
      unless video_gen.ready_for_generation?
        raise "必要なファイルが揃っていません"
      end

      # 一時ファイルにダウンロード
      audio_path = download_to_temp(video_gen.recording.generated_audio, "audio_#{video_gen.id}")
      image_path = download_to_temp(video_gen.thumbnail_image, "image_#{video_gen.id}")
      output_path = Rails.root.join('tmp', "video_#{video_gen.id}.mp4").to_s

      # FFmpegで動画生成
      generate_video(
        audio_path: audio_path,
        image_path: image_path,
        output_path: output_path
      )

      # 生成した動画をActive Storageにアップロード
      video_gen.generated_video.attach(
        io: File.open(output_path),
        filename: "video_#{video_gen.id}.mp4",
        content_type: 'video/mp4'
      )

      video_gen.update!(status: :generated)
      Rails.logger.info "VideoGenerationJob: Finished video ##{video_generation_id}"

    rescue => e
      Rails.logger.error "VideoGenerationJob: Error - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      video_gen.update!(status: :failed, error_message: e.message)
    ensure
      cleanup_temp_files([audio_path, image_path, output_path])
    end
  end

  private

  def download_to_temp(attachment, filename)
    temp_file = Tempfile.new([filename, File.extname(attachment.filename.to_s)])
    temp_file.binmode
    temp_file.write(attachment.download)
    temp_file.flush
    temp_file.path
  end

  def generate_video(audio_path:, image_path:, output_path:)
    # 画像を音声の長さに合わせて動画化
    cmd = <<~CMD.squish
      ffmpeg -y
      -loop 1
      -i "#{image_path}"
      -i "#{audio_path}"
      -c:v libx264
      -tune stillimage
      -c:a aac
      -b:a 192k
      -pix_fmt yuv420p
      -shortest
      "#{output_path}"
    CMD

    Rails.logger.info "VideoGenerationJob: FFmpeg command: #{cmd}"

    stdout, stderr, status = Open3.capture3(cmd)

    unless status.success?
      Rails.logger.error "VideoGenerationJob: FFmpeg error: #{stderr}"
      raise "FFmpegエラー: #{stderr}"
    end

    Rails.logger.info "VideoGenerationJob: FFmpeg success"
  end

  def cleanup_temp_files(paths)
    paths.compact.each do |path|
      File.delete(path) if path && File.exist?(path)
    rescue => e
      Rails.logger.warn "VideoGenerationJob: 一時ファイル削除エラー: #{e.message}"
    end
  end
end
