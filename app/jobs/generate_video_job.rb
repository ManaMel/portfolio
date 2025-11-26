class GenerateVideoJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find(recording_id)
    audio = recording.audio_file

    # 一時ファイル
    audio_path = Rails.root.join("tmp", "audio_#{recording.id}.wav")
    image_path = Rails.root.join("app/assets/images/background.png")
    output_path = Rails.root.join("tmp", "video_#{recording.id}.mp4")

    # ActiveStorage → temp 保存
    File.open(audio_path, "wb") do |file|
      file.write(audio.download)
    end

    # ffmpeg コマンド
    system <<~CMD
      ffmpeg -y -loop 1 -i #{image_path} \
      -i #{audio_path} \
      -c:v libx264 -tune stillimage \
      -c:a aac -b:a 192k \
      -pix_fmt yuv420p \
      -shortest #{output_path}
    CMD

    # Videoモデル作成 & attach
    video = recording.build_video
    video.file.attach(io: File.open(output_path), filename: "output.mp4")
    video.save!

    # 一時ファイル削除
    File.delete(audio_path) if File.exist?(audio_path)
    File.delete(output_path) if File.exist?(output_path)
  end
end
