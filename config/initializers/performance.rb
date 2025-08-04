# Performance and caching configuration
Rails.application.configure do
  # Enable fragment caching in all environments
  config.action_controller.perform_caching = true
  
  # Use Redis for caching if available
  if ENV['REDIS_URL'].present?
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'],
      expires_in: 1.hour,
      namespace: 'pirate_rails_cache',
      pool_size: 5,
      pool_timeout: 5,
      reconnect_attempts: 3
    }
  else
    config.cache_store = :memory_store, { size: 64.megabytes }
  end

  # Configure Active Storage for better performance
  config.active_storage.variant_processor = :mini_magick
  config.active_storage.precompile_assets = false

  # Database query optimization
  config.active_record.strict_loading_by_default = true if Rails.env.development?
  
  # Background job configuration
  config.active_job.queue_adapter = :sidekiq if defined?(Sidekiq)
  
  # Security configurations
  config.force_ssl = true if Rails.env.production?
  config.ssl_options = { hsts: { subdomains: true } } if Rails.env.production?
end

# Rate limiting store
RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 10.megabytes)

# Cache key helpers
module CacheHelper
  def self.user_movie_key(user_id, movie_id)
    "movie_#{movie_id}_user_#{user_id}"
  end

  def self.search_key(params, user_role)
    "search_#{Digest::MD5.hexdigest(params.to_query)}_#{user_role}"
  end

  def self.series_movies_key(series_id)
    "series_#{series_id}_movies"
  end
end
