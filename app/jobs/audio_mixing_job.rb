class AudioMixingJob < ApplicationJob
  queue_as :default

  # ★ 引数は recording_id のみで十分です
  def perform(recording_id)
    recording = Recording.find(recording_id)

    original = recording.original_audio
    accomp   = recording.accompaniment

    # 録音と伴奏の両方が必要
    return unless original&.attached? && accomp&.attached?

    # ActiveStorage 内部パスを取得
    original_path = ActiveStorage::Blob.service.send(:path_for, original.blob.key)
    accomp_path   = ActiveStorage::Blob.service.send(:path_for, accomp.blob.key)

    # 出力パス
    out_path = Rails.root.join("tmp", "mixed_#{SecureRandom.hex}.wav")

    # ffmpeg ミックス
    system <<~CMD
      ffmpeg -y \
      -i "#{original_path}" \
      -i "#{accomp_path}" \
      -filter_complex "amix=inputs=2:duration=longest" \
      "#{out_path}"
    CMD

    # ActiveStorage に保存
    recording.mixed_audio.attach(
      io: File.open(out_path),
      filename: "mixed_#{recording.id}.wav",
      content_type: "audio/wav"
    )

    # tmp 削除
    File.delete(out_path) if File.exist?(out_path)
  end
end
