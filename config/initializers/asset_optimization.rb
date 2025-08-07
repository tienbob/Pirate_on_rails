# Asset Performance Optimizations
Rails.application.configure do
  # HTTP/2 Server Push for critical resources
  # Disabled for Docker development - Nginx handles SSL termination
  # config.force_ssl = true if Rails.env.production?
  
  # Asset precompilation for cinema bundle
  if Rails.env.production?
    config.assets.precompile += %w[
      cinema_bundle.css
      application.css
      *.png *.jpg *.jpeg *.gif *.svg
    ]
  end
  
  # Cache configuration for assets
  config.action_controller.perform_caching = true
  
  # Enable browser caching for static assets
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=2592000', # 30 days
    'Expires' => 30.days.from_now.to_formatted_s(:rfc822)
  } if Rails.env.production?
end

# Custom middleware for asset optimization
class AssetOptimizationMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Add performance headers for CSS files
    if env['PATH_INFO'].include?('.css')
      headers['X-Content-Type-Options'] = 'nosniff'
      headers['Cache-Control'] = 'public, max-age=31536000, immutable' # 1 year
    end
    
    # Temporarily disable preload hints to fix browser warnings
    # if env['PATH_INFO'] == '/' || env['PATH_INFO'].include?('/movies')
    #   link_header = [
    #     '</assets/cinema_bundle.css>; rel=preload; as=style',
    #     '</assets/application.js>; rel=preload; as=script'
    #   ].join(', ')
    #   headers['Link'] = link_header
    # end
    
    [status, headers, response]
  end
end

# Add middleware in production
Rails.application.config.middleware.use AssetOptimizationMiddleware if Rails.env.production?
