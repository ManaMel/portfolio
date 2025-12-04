# SidekiqのRedis接続設定を修正します。
# 接続URLは環境変数から取得するか、Docker Composeのサービス名 'redis' を使います。
# Docker環境ではサービス名がホスト名として機能します。
redis_url = ENV.fetch('REDIS_URL', 'redis://redis:6379/0')

# Sidekiqサーバー側の設定（ジョブを処理するワーカー用）
Sidekiq.configure_server do |config|
  # Redis設定は、クライアントが正しく処理できるように、シンプルなハッシュとして渡します。
  config.redis = {
    url: redis_url,
    # サーバー側は通常、同時実行スレッド数に合わせて接続プールサイズを設定します。
    size: ENV.fetch('SIDEKIQ_POOL_SIZE', 10).to_i,
    # 問題の原因となりうる、Sidekiqが期待しない余計なキー（例: pool_name）は削除します。
  }
end

# Sidekiqクライアント側の設定（ジョブをキューに入れるアプリケーション側用）
Sidekiq.configure_client do |config|
  # クライアント側は接続プールサイズを小さく保つのが一般的です。
  config.redis = {
    url: redis_url,
    size: ENV.fetch('SIDEKIQ_CLIENT_POOL_SIZE', 1).to_i
  }
end

# 注: 以前のSidekiqのバージョンで使用されていたRedis接続プールオプションの
# 誤った残骸や、過度に複雑な設定ロジックがエラーを引き起こすことが多いため、
# 上記のように、必要最小限のシンプルな設定にすることをお勧めします。