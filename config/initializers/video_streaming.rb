# Video streaming and memory management configuration
Rails.application.configure do
  # Prevent ActiveStorage from loading large files into memory
  config.to_prepare do
    # Override ActiveStorage proxy controller to prevent memory issues
    ActiveStorage::Blobs::ProxyController.class_eval do
      private
      
      def stream(blob)
        # Only redirect video files to custom streaming, not images
        if blob.byte_size > 10.megabytes && blob.content_type.to_s.start_with?('video/')
          # Redirect to our custom streaming controller for large video files
          redirect_to "/movies/#{params[:id] || 'unknown'}/video_stream", allow_other_host: false
        else
          super
        end
      end
    end
    
    # Optimize ActiveStorage redirect controller
    ActiveStorage::Blobs::RedirectController.class_eval do
      def show
        expires_in ActiveStorage.service_urls_expire_in
        
        # Only use custom streaming for large video files, not images
        if @blob.byte_size > 10.megabytes && @blob.content_type.to_s.start_with?('video/')
          redirect_to "/movies/#{params[:movie_id] || 'unknown'}/video_stream", allow_other_host: false
        else
          redirect_to @blob.url(disposition: params[:disposition]), allow_other_host: true
        end
      end
    end
  end
end

# Configure ActiveRecord for better memory management
Rails.application.config.after_initialize do
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    # Optimize database connection for video streaming
    if connection.adapter_name == "SQLite"
      connection.execute("PRAGMA cache_size = 10000")
      connection.execute("PRAGMA temp_store = memory")
      connection.execute("PRAGMA mmap_size = 268435456") # 256MB mmap
    end
  end
end
