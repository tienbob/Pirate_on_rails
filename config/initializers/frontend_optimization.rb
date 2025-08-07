# Frontend Performance Optimization Configuration
Rails.application.configure do
  # Enable asset compression and caching
  config.assets.compress = true
  config.assets.compile = true if Rails.env.development? # Allow compilation in dev
  config.assets.digest = true
  
  # Enable gzip compression
  config.middleware.use Rack::Deflater
  
  # Cache static assets aggressively
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000'
  }
  
  # Enable fragment caching
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store, { size: 64.megabytes }
  
  # Optimize Active Storage
  config.active_storage.variant_processor = :mini_magick
  config.active_storage.web_image_content_types = %w[image/png image/jpeg image/gif image/webp]
  
  # Performance optimizations for development
  if Rails.env.development?
    # Reduce asset compilation overhead
    config.assets.check_precompiled_asset = false
    
    # Enable asset caching in development
    config.assets.cache_store = :file_store, Rails.root.join('tmp', 'cache', 'assets')
  end
  
  # Enable HTTP/2 Server Push for critical assets
  # Disabled for Docker development - Nginx handles SSL termination
  if Rails.env.production?
    # config.force_ssl = true
    config.ssl_options = {
      hsts: { subdomains: true, preload: true, expires: 1.year }
    }
  end
end

# Optimize database queries for frontend
ActiveRecord::Base.class_eval do
  # Add method to check if association is loaded efficiently
  def association_loaded?(association_name)
    association(association_name).loaded?
  end
end

# Basic Active Storage optimization
if defined?(ActiveStorage)
  # Optimize variant processing for web images
  Rails.application.config.active_storage.variant_processor = :mini_magick
  Rails.application.config.active_storage.web_image_content_types = %w[image/png image/jpeg image/gif image/webp]
end
