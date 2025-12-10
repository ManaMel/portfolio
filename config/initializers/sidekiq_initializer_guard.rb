# config/environments/production.rb から移動
Rails.application.config.active_job.queue_adapter = :sidekiq
# Rails.application.config.active_job.queue_name_prefix = "myapp_production"

# Sidekiqは独自のイニシャライザ（通常は config/initializers/sidekiq.rb）でRedisを設定します。
