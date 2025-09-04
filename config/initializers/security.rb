# Security configuration for the application
Rails.application.configure do
  # Rate limiting configuration
  config.rate_limiting = {
    api_requests: { limit: 100, period: 1.hour },
    login_attempts: { limit: 5, period: 15.minutes },
    payment_attempts: { limit: 10, period: 1.hour },
    search_requests: { limit: 30, period: 1.minute },
    view_requests: { limit: 100, period: 1.hour }
  }

  # Session security - configured for external payment provider compatibility
  config.session_store :cookie_store,
    key: "_pirate_rails_session",
    httponly: true,
    secure: false,  # Disabled for Docker development without SSL
    same_site: :lax,  # Changed from :strict to :lax for Stripe redirect compatibility
    expire_after: 24.hours  # Set explicit expiration to prevent session loss during redirects

  # Configure secure headers
  # Disabled for Docker development - Nginx handles SSL termination
  # config.force_ssl = true if Rails.env.production?
end

# Security helper methods
module SecurityHelper
  # Check if IP is rate limited
  def self.rate_limited?(ip, key, limit, period)
    cache_key = "rate_limit_#{ip}_#{key}"
    current_count = Rails.cache.read(cache_key).to_i

    if current_count >= limit
      true
    else
      Rails.cache.increment(cache_key, 1, expires_in: period)
      false
    end
  end

  # Log security events
  def self.log_security_event(event_type, details = {})
    Rails.logger.security.info({
      event: event_type,
      timestamp: Time.current.iso8601,
      details: details
    }.to_json) if Rails.logger.respond_to?(:security)
  end

  # Validate file upload security
  def self.safe_file_upload?(file)
    return false unless file

    # Check file size (max 100MB for videos)
    return false if file.size > 100.megabytes

    # Check content type
    allowed_types = %w[
      video/mp4 video/mpeg video/quicktime video/x-msvideo
      video/webm video/ogg
    ]
    return false unless allowed_types.include?(file.content_type)

    # Check file extension
    allowed_extensions = %w[.mp4 .mpeg .mov .avi .webm .ogv]
    extension = File.extname(file.original_filename).downcase
    allowed_extensions.include?(extension)
  end

  # Sanitize user input
  def self.sanitize_input(input)
    return input unless input.is_a?(String)

    # Remove potential XSS
    ActionController::Base.helpers.sanitize(input, tags: [])
  end
end

# Custom logger for security events
if Rails.env.production?
  security_logger = Logger.new("#{Rails.root}/log/security.log")
  security_logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime.iso8601} [#{severity}] #{msg}\n"
  end
  Rails.logger.define_singleton_method(:security) { security_logger }
end
