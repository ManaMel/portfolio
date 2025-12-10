class AudioMixingJob < ApplicationJob
  queue_as :default

 def perform(recording_id, delay_seconds = nil, vocal_gain = nil)
    recording = Recording.find(recording_id)
    
    Rails.logger.info "AudioMixingJob: Recording ##{recording_id}, status=#{recording.status}"
    
    if recording.generated?
      Rails.logger.info "AudioMixingJob: Already generated, skipping"
      return
    end
    
    begin
      Rails.logger.info "AudioMixingJob: Start mixing Recording #{recording_id}"
      
      # ★★★ 引数から値を使用、なければDBから取得 ★★★
      delay_seconds ||= recording.recording_delay || 0.0
      vocal_gain ||= recording.vocal_gain || 0.5
      
      Rails.logger.info "AudioMixingJob: Using delay=#{delay_seconds}s, vocal_gain=#{vocal_gain}"
      
      unless recording.original_audio.attached? && recording.accompaniment.attached?
        raise "必要なファイルが揃っていません"
      end
      
      original_path = download_to_temp(recording.original_audio, "original_#{recording.id}.wav")
      accompaniment_path = download_to_temp(recording.accompaniment, "accompaniment_#{recording.id}")
      output_path = Rails.root.join('tmp', "mixed_#{recording.id}.mp3").to_s
      
      mix_audio(
        original_path: original_path,
        accompaniment_path: accompaniment_path,
        output_path: output_path,
        delay_seconds: delay_seconds,
        vocal_gain: vocal_gain
      )
      
      recording.generated_audio.attach(
        io: File.open(output_path),
        filename: "mixed_#{recording.id}.mp3",
        content_type: 'audio/mpeg'
      )
      
      recording.update!(status: :generated)
      Rails.logger.info "AudioMixingJob: Finished Recording #{recording_id}"
      
    rescue => e
      Rails.logger.error "AudioMixingJob: Error - Recording #{recording_id}, Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      recording.update!(status: :failed, error_message: e.message)
    ensure
      cleanup_temp_files([original_path, accompaniment_path, output_path])
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

  def mix_audio(original_path:, accompaniment_path:, output_path:, delay_seconds:, vocal_gain:)
    # 伴奏のゲインは (1 - vocal_gain) で計算
    accompaniment_gain = 1.0 - vocal_gain
    
    Rails.logger.info "AudioMixingJob: Mixing with delay=#{delay_seconds}s, vocal_gain=#{vocal_gain}, accompaniment_gain=#{accompaniment_gain}"
    
    # FFmpegコマンドを構築
    cmd = build_ffmpeg_command(
      original_path: original_path,
      accompaniment_path: accompaniment_path,
      output_path: output_path,
      delay_seconds: delay_seconds,
      vocal_gain: vocal_gain,
      accompaniment_gain: accompaniment_gain
    )
    
    Rails.logger.info "AudioMixingJob: FFmpeg command: #{cmd}"
    
    # FFmpegを実行
    stdout, stderr, status = Open3.capture3(cmd)
    
    unless status.success?
      Rails.logger.error "AudioMixingJob: FFmpeg error: #{stderr}"
      raise "FFmpegエラー: #{stderr}"
    end
    
    Rails.logger.info "AudioMixingJob: FFmpeg success"
  end

  def build_ffmpeg_command(original_path:, accompaniment_path:, output_path:, delay_seconds:, vocal_gain:, accompaniment_gain:)
    if delay_seconds >= 0
      delay_ms = (delay_seconds * 1000).to_i
      # モノラル/ステレオ両対応（最初にaformatでステレオ化）
      <<~CMD.squish
        ffmpeg -y
        -i "#{accompaniment_path}"
        -i "#{original_path}"
        -filter_complex "[1:a]aformat=channel_layouts=stereo,adelay=#{delay_ms}|#{delay_ms},volume=#{vocal_gain}[a1];[0:a]aformat=channel_layouts=stereo,volume=#{accompaniment_gain}[a0];[a0][a1]amix=inputs=2:duration=longest:dropout_transition=2"
        -ac 2
        -b:a 192k
        "#{output_path}"
      CMD
    else
      offset = delay_seconds.abs
      <<~CMD.squish
        ffmpeg -y
        -i "#{accompaniment_path}"
        -i "#{original_path}"
        -filter_complex "[1:a]aformat=channel_layouts=stereo,atrim=start=#{offset},volume=#{vocal_gain}[a1];[0:a]aformat=channel_layouts=stereo,volume=#{accompaniment_gain}[a0];[a0][a1]amix=inputs=2:duration=longest:dropout_transition=2"
        -ac 2
        -b:a 192k
        "#{output_path}"
      CMD
    end
  end

  def cleanup_temp_files(paths)
    paths.compact.each do |path|
      File.delete(path) if path && File.exist?(path)
    rescue => e
      Rails.logger.warn "AudioMixingJob: 一時ファイル削除エラー: #{e.message}"
    end
  end
end