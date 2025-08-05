class VideoStreamingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Skip certain middleware for video streaming requests
    if video_streaming_request?(request)
      # Skip CSRF protection and other non-essential middleware
      env['action_controller.skip_csrf_protection'] = true
      
      # Set optimized headers for video streaming
      env['HTTP_X_SENDFILE_TYPE'] = 'X-Accel-Redirect' if env['HTTP_X_SENDFILE_TYPE'].nil?
    end
    
    @app.call(env)
  end
  
  private
  
  def video_streaming_request?(request)
    request.path.include?('/video_stream') || 
    request.path.start_with?('/stream/') ||
    (request.path.include?('/movies/') && request.env['HTTP_RANGE'].present?)
  end
end
