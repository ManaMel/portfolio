class AudioMixingJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find(recording_id)

    # original_audio と accompaniment が揃っていない場合は失敗扱いにする
    unless recording.original_audio.attached? && recording.accompaniment.attached?
      # ログに出力して、なぜ処理をスキップしたか確認できるようにする
      Rails.logger.warn("[AudioMixingJob] Skipping job #{recording_id}: Missing attachments.")
      recording.update(status: :created)
      return
    end

    # ステータスを「生成中」に変更
    recording.update(status: :generating)

    original = recording.original_audio
    accomp   = recording.accompaniment

    # S3からファイルをダウンロードし、ローカルの一時ファイルとして使用
    # original.open と accomp.open は、S3からダウンロードしたファイルの一時パスを提供
    original.open do |original_tempfile|
      accomp.open do |accomp_tempfile|
        
        # S3からダウンロードされた一時ファイルのパス
        original_path = original_tempfile.path
        accomp_path   = accomp_tempfile.path

        # 出力テンポラリファイル
        out_path = Rails.root.join("tmp", "mixed_#{SecureRandom.hex}.wav").to_s

        begin
          Rails.logger.info("[AudioMixingJob] Starting FFmpeg mixing process.")
          
          # ffmpeg ミックス処理を実行
          # パスを文字列として安全に渡すため、Shellwords.escape を使用することが理想的ですが、
          # Rubyのsystemコマンドとダブルクォートでひとまず対処します。
          system <<~CMD
            ffmpeg -y \
            -i "#{original_path}" \
            -i "#{accomp_path}" \
            -filter_complex "amix=inputs=2:duration=longest" \
            "#{out_path}"
          CMD

          # 生成失敗時（ファイル未作成、またはFFmpegがエラーを返した）
          unless File.exist?(out_path) && $?.success? # $?.success? でFFmpegの終了コードを確認
            Rails.logger.error("[AudioMixingJob] FFmpeg failed to create output file.")
            recording.update(status: :created)
            return
          end

          # 生成音声をS3に保存
          recording.generated_audio.attach(
            io: File.open(out_path),
            filename: "mixed_#{recording.id}.wav",
            content_type: "audio/wav"
          )

          # 成功したので status を変更！
          recording.update(status: :generated)
          Rails.logger.info("[AudioMixingJob] Successfully generated and uploaded mixed audio.")

        rescue => e
          # 例外発生時はステータスを初期化し、エラーをログ
          recording.update(status: :created)
          Rails.logger.error("[AudioMixingJob] Runtime Error: #{e.message}")

        ensure
          # openブロックを抜けると、一時ファイル (original_tempfile, accomp_tempfile) は
          # Active Storageによって自動的に削除されます。
          # out_path のみを明示的に削除します。
          if File.exist?(out_path)
            File.delete(out_path) 
            Rails.logger.info("[AudioMixingJob] Deleted temporary output file: #{out_path}")
          end
        end
      end # accomp.open ブロック終了
    end # original.open ブロック終了
  end
end