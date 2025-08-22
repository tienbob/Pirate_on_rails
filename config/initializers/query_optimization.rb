# Query optimization settings for better performance
Rails.application.configure do
  # Log slow queries in development
  if Rails.env.development?
    # Enable bullet gem for N+1 query detection if available
    if defined?(Bullet)
      config.after_initialize do
        Bullet.enable = true
        Bullet.alert = true
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end
    end

    # Log queries that take longer than 100ms
    ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
      duration = finished - started
      if duration > 0.1 # 100ms
        Rails.logger.warn "SLOW QUERY (#{(duration * 1000).round(2)}ms): #{data[:sql]}"
      end
    end
  end
end
