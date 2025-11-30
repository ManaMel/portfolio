class AudioMixingJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find(recording_id)

    # original_audio と accompaniment が揃っていない場合は失敗扱いにする
    unless recording.original_audio.attached? && recording.accompaniment.attached?
      recording.update(status: :created)
      return
    end

    # ステータスを「生成中」に変更
    recording.update(status: :generating)

    original = recording.original_audio
    accomp   = recording.accompaniment

    # ActiveStorage 内部の実際のファイルパス取得
    original_path = ActiveStorage::Blob.service.send(:path_for, original.blob.key)
    accomp_path   = ActiveStorage::Blob.service.send(:path_for, accomp.blob.key)

    # 出力テンポラリファイル
    out_path = Rails.root.join("tmp", "mixed_#{SecureRandom.hex}.wav")

    begin
      # ffmpeg ミックス処理
      system <<~CMD
        ffmpeg -y \
        -i "#{original_path}" \
        -i "#{accomp_path}" \
        -filter_complex "amix=inputs=2:duration=longest" \
        "#{out_path}"
      CMD

      # 生成失敗時（ファイル未作成）
      unless File.exist?(out_path)
        recording.update(status: :created)
        return
      end

      # 生成音声を保存
      recording.generated_audio.attach(
        io: File.open(out_path),
        filename: "mixed_#{recording.id}.wav",
        content_type: "audio/wav"
      )

      # ★ 成功したので status を変更！
      recording.update(status: :generated)

    rescue => e
      # 例外発生時はステータスを初期化
      recording.update(status: :created)
      Rails.logger.error("[AudioMixingJob] Error: #{e.message}")

    ensure
      # tmp ファイル削除
      File.delete(out_path) if File.exist?(out_path)
    end
  end
end
