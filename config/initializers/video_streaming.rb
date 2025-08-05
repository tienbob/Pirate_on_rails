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

# Configure ActiveRecord for better memory management and SQLite performance
Rails.application.config.after_initialize do
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    # Optimize database connection for video streaming and general performance
    if connection.adapter_name == "SQLite"
      # Memory and cache optimizations
      connection.execute("PRAGMA cache_size = -64000")      # 64MB cache (negative = KB)
      connection.execute("PRAGMA temp_store = memory")      # Store temp tables in memory
      connection.execute("PRAGMA mmap_size = 536870912")    # 512MB mmap (doubled)
      
      # Performance optimizations
      connection.execute("PRAGMA synchronous = NORMAL")     # Faster than FULL, safer than OFF
      connection.execute("PRAGMA journal_mode = WAL")       # Write-Ahead Logging for better concurrency
      connection.execute("PRAGMA wal_autocheckpoint = 1000") # Auto checkpoint every 1000 pages
      connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")  # Initial checkpoint
      
      # Query optimization
      connection.execute("PRAGMA optimize")                 # Optimize query planner
      connection.execute("PRAGMA auto_vacuum = INCREMENTAL") # Incremental auto vacuum
      
      # Connection pool optimizations
      connection.execute("PRAGMA busy_timeout = 30000")     # 30 second timeout for locks
      
      Rails.logger.info "SQLite optimizations applied: WAL mode, 64MB cache, 512MB mmap"
    end
  end
end
