# Sidekiq設定ファイル
# Redisへの接続設定と、アセットプリコンパイル時の処理スキップガードを含みます。

# ActiveSupportの拡張メソッド（present?）を初期化段階で利用できるようにする
require 'active_support/core_ext/object/blank' 

# 環境変数 SKIP_REDIS_CONFIG が存在する場合、このブロックの処理をスキップ
# これにより、assets:precompile実行時にRedis接続を試みてビルドが失敗するのを防ぎます。
if ENV['SKIP_REDIS_CONFIG'].present?
  Rails.logger.info "Skipping Sidekiq/Redis configuration (SKIP_REDIS_CONFIG is set)."
  return
end

# ActiveJob のアダプタ設定
Rails.application.config.active_job.queue_adapter = :sidekiq

# Redis接続URLの決定。Docker Compose環境では 'redis://redis:6379/1' となることを想定
REDIS_CONNECTION_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
SIDEKIQ_NAMESPACE = "portfolio_sidekiq"

# --- Sidekiqサーバー側の設定 (WebプロセスとSidekiqプロセスで使用) ---
Sidekiq.configure_server do |config|
  # Sidekiq 8.xで安定しやすいブロック形式を使用してRedis接続を設定します。
  config.redis do |redis_config|
    redis_config.url = REDIS_CONNECTION_URL
    redis_config.namespace = SIDEKIQ_NAMESPACE
  end

  Rails.logger.info "Sidekiq server will connect to Redis at: #{REDIS_CONNECTION_URL} with namespace: #{SIDEKIQ_NAMESPACE}"
end

# --- Sidekiqクライアント側の設定 (ActiveJobを呼ぶ全てのコードで使用) ---
Sidekiq.configure_client do |config|
  config.redis do |redis_config|
    redis_config.url = REDIS_CONNECTION_URL
    redis_config.namespace = SIDEKIQ_NAMESPACE
  end
end