# Sidekiq設定ファイル
# Redisへの接続設定と、アセットプリコンパイル時の処理スキップガードを含みます。

# 環境変数 SKIP_REDIS_CONFIG が存在する場合、このブロックの処理をスキップ
# これにより、assets:precompile実行時にRedis接続を試みてビルドが失敗するのを防ぎます。
if ENV['SKIP_REDIS_CONFIG'].present?
  Rails.logger.info "Skipping Sidekiq/Redis configuration during asset precompile/Docker build."
  return
end

# ActiveJob のアダプタ設定
Rails.application.config.active_job.queue_adapter = :sidekiq

# --- Sidekiqサーバー側の設定 (WebプロセスとSidekiqプロセスで使用) ---
Sidekiq.configure_server do |config|
  # REDIS_URL環境変数（Renderなどで設定）を使用してRedisに接続
  # 開発環境用に localhost のフォールバックを含めます。
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

  Rails.logger.info "Sidekiq server will connect to Redis at: #{config.redis[:url]}"
end

# --- Sidekiqクライアント側の設定 (ActiveJobを呼ぶ全てのコードで使用) ---
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
end