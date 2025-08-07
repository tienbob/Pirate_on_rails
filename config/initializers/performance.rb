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

  # Database query optimization - disabled for performance
  # config.active_record.strict_loading_by_default = true if Rails.env.development?
  
  # Background job configuration
  config.active_job.queue_adapter = :sidekiq if defined?(Sidekiq)
  
  # Security configurations
  # Disabled for Docker development - Nginx handles SSL termination
  # config.force_ssl = true if Rails.env.production?
  # config.ssl_options = { hsts: { subdomains: true } } if Rails.env.production?
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

# Performance monitoring for slow operations
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
  duration = finished - started
  
  if duration > 1.0 # Log requests taking more than 1 second
    controller = data[:controller]
    action = data[:action]
    status = data[:status]
    
    Rails.logger.warn "SLOW REQUEST: #{controller}##{action} took #{duration.round(2)}s (Status: #{status})"
    
    # Log specific timing breakdown
    if data[:db_runtime]
      db_percentage = (data[:db_runtime] / (duration * 1000)) * 100
      Rails.logger.warn "  - Database: #{data[:db_runtime].round(2)}ms (#{db_percentage.round(1)}%)"
    end
    
    if data[:view_runtime]
      view_percentage = (data[:view_runtime] / (duration * 1000)) * 100
      Rails.logger.warn "  - View rendering: #{data[:view_runtime].round(2)}ms (#{view_percentage.round(1)}%)"
    end
    
    # Calculate overhead time (non-DB, non-view)
    overhead_time = duration * 1000 - (data[:db_runtime] || 0) - (data[:view_runtime] || 0)
    overhead_percentage = (overhead_time / (duration * 1000)) * 100
    Rails.logger.warn "  - Overhead: #{overhead_time.round(2)}ms (#{overhead_percentage.round(1)}%)"
  end
end

# Monitor large query results
ActiveSupport::Notifications.subscribe "instantiation.active_record" do |name, started, finished, unique_id, data|
  if data[:record_count] > 100
    Rails.logger.info "Large query result: #{data[:class_name]} returned #{data[:record_count]} records"
  end
end
