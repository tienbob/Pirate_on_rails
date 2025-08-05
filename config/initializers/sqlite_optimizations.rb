# SQLite Performance Optimizations
Rails.application.configure do
  # Apply SQLite optimizations to all new connections
  config.after_initialize do
    if ActiveRecord::Base.connection.adapter_name == "SQLite"
      # Set up connection callback for SQLite optimization
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
          def configure_connection
            super
            
            # Apply performance optimizations to every new connection
            execute("PRAGMA cache_size = -64000")      # 64MB cache
            execute("PRAGMA temp_store = memory")      # Memory temp storage
            execute("PRAGMA mmap_size = 536870912")    # 512MB mmap
            execute("PRAGMA synchronous = NORMAL")     # Balanced safety/performance
            execute("PRAGMA journal_mode = WAL")       # Write-Ahead Logging
            execute("PRAGMA busy_timeout = 30000")     # 30 second busy timeout
            execute("PRAGMA wal_autocheckpoint = 1000") # Auto checkpoint
            execute("PRAGMA optimize")                 # Optimize query planner stats
            
            Rails.logger.debug "SQLite connection optimized"
          end
        end
      end
    end
  end
end
