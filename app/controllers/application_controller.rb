class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Temporarily disabled for performance debugging
  # before_action :log_user_activity_optimized
  
  include Pundit::Authorization
  # Temporarily disabled CSRF protection for proxy testing
  # protect_from_forgery with: :exception, prepend: true
  
  # Security headers
  # before_action :set_security_headers  # Temporarily disabled to debug performance

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from StandardError, with: :handle_standard_error unless Rails.env.development? || Rails.env.test?

  # Health check endpoint for Docker and monitoring
  def health
    # Basic health checks
    checks = {
      database: database_healthy?,
      redis: redis_healthy?,
      storage: storage_healthy?
    }
    
    all_healthy = checks.values.all?
    
    status = all_healthy ? :ok : :service_unavailable
    
    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      timestamp: Time.current.iso8601,
      checks: checks,
      version: Rails.application.config.version || 'unknown'
    }, status: status
  end

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: series_index_path)
  end

  def record_not_found
    flash[:alert] = "The requested resource was not found."
    redirect_to series_index_path
  end

  def handle_standard_error(exception)
    # Log the error with context
    Rails.logger.error "Standard Error: #{exception.message}"
    Rails.logger.error "Backtrace: #{exception.backtrace.join("\n")}"
    Rails.logger.error "User: #{current_user&.email || 'Anonymous'}"
    Rails.logger.error "Request: #{request.method} #{request.url}"
    Rails.logger.error "Params: #{params.inspect}"
    
    # Send to error tracking service (Sentry, Rollbar, etc.)
    # Sentry.capture_exception(exception) if defined?(Sentry)
    
    flash[:alert] = "Something went wrong. Please try again."
    redirect_back(fallback_location: series_index_path)
  end

  def set_security_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    # Content Security Policy (adjust based on your needs)
    if Rails.env.development?
      # More permissive CSP for development
      response.headers['Content-Security-Policy'] = [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com https://cdn.jsdelivr.net",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net",
        "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com",
        "img-src 'self' data: https:",
        "media-src 'self' blob:",
        "connect-src 'self' https://api.stripe.com",
        "frame-src https://js.stripe.com"
      ].join('; ')
    else
      # Stricter CSP for production
      response.headers['Content-Security-Policy'] = [
        "default-src 'self'",
        "script-src 'self' https://js.stripe.com",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net",
        "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com",
        "img-src 'self' data: https:",
        "media-src 'self' blob:",
        "connect-src 'self' https://api.stripe.com",
        "frame-src https://js.stripe.com"
      ].join('; ')
    end
  end

  def log_user_activity_optimized
    return unless current_user && !devise_controller?
    
    # Use async logging and reduce database writes
    Rails.logger.info "User Activity: #{current_user.email} - #{request.method} #{request.path}"
    
    # Update last seen timestamp only once per 15 minutes to reduce DB pressure
    last_seen_cache_key = "user_last_seen_#{current_user.id}"
    last_update = Rails.cache.read(last_seen_cache_key)
    
    if last_update.nil? || last_update < 15.minutes.ago
      # Use update_column to skip callbacks and validations for performance
      if current_user.respond_to?(:last_seen_at)
        current_user.update_column(:last_seen_at, Time.current)
      end
      Rails.cache.write(last_seen_cache_key, Time.current, expires_in: 15.minutes)
    end
  end

  # Keep the original method for reference
  def log_user_activity
    return unless current_user && !devise_controller?
    
    # Log user activity for analytics/security
    Rails.logger.info "User Activity: #{current_user.email} - #{request.method} #{request.path}"
    
    # Update last seen timestamp only once per 5 minutes to reduce DB writes
    last_seen_cache_key = "user_last_seen_#{current_user.id}"
    last_update = Rails.cache.read(last_seen_cache_key)
    
    if last_update.nil? || last_update < 5.minutes.ago
      current_user.touch(:last_seen_at) if current_user.respond_to?(:last_seen_at)
      Rails.cache.write(last_seen_cache_key, Time.current, expires_in: 5.minutes)
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role])
  end

  # Rate limiting helper
  def check_general_rate_limit(key_suffix: '', limit: 100, period: 1.hour)
    rate_limit_key = "rate_limit_#{request.remote_ip}_#{current_user&.id}_#{key_suffix}"
    
    current_count = Rails.cache.read(rate_limit_key).to_i
    if current_count >= limit
      flash[:alert] = 'Too many requests. Please try again later.'
      redirect_back(fallback_location: series_index_path)
      return false
    end
    
    Rails.cache.increment(rate_limit_key, 1, expires_in: period)
    true
  end

  # Helper to check if user is admin
  def require_admin!
    unless current_user&.admin?
      flash[:alert] = 'You are not authorized to access this area.'
      redirect_to series_index_path
    end
  end

  # Helper to check if user is authenticated
  def require_authentication!
    unless current_user
      flash[:alert] = 'You must be logged in to access this page.'
      redirect_to new_user_session_path
    end
  end

  # Helper method to get user's subscription information
  def get_user_subscription_info(user)
    return nil unless user&.pro?

    begin
      # Search for user's customer in Stripe
      customers = Stripe::Customer.list(email: user.email, limit: 1)
      return nil if customers.data.empty?

      customer = customers.data.first
      
      # Get active subscriptions for this customer
      subscriptions = Stripe::Subscription.list(
        customer: customer.id,
        status: 'active',
        limit: 1
      )
      
      return nil if subscriptions.data.empty?
      
      subscription = subscriptions.data.first
      
      # Safely extract subscription data with proper nil checks
      subscription_data = {
        subscription_id: subscription.id,
        customer_id: customer.id,
        status: subscription.status,
        current_period_start: nil,
        current_period_end: nil,
        cancel_at_period_end: false,
        cancelled_at: nil,
        amount: nil,
        currency: 'usd',
        interval: 'month'
      }
      
      # Safely set period dates
      if subscription.respond_to?(:current_period_start) && subscription.current_period_start
        subscription_data[:current_period_start] = Time.at(subscription.current_period_start)
      end
      
      if subscription.respond_to?(:current_period_end) && subscription.current_period_end
        subscription_data[:current_period_end] = Time.at(subscription.current_period_end)
      end
      
      # Safely set cancellation info
      if subscription.respond_to?(:cancel_at_period_end)
        subscription_data[:cancel_at_period_end] = subscription.cancel_at_period_end
      end
      
      if subscription.respond_to?(:cancelled_at) && subscription.cancelled_at
        subscription_data[:cancelled_at] = Time.at(subscription.cancelled_at)
      end
      
      # Safely set pricing info
      if subscription.items&.data&.first&.price
        price = subscription.items.data.first.price
        subscription_data[:amount] = price.unit_amount if price.respond_to?(:unit_amount)
        subscription_data[:currency] = price.currency if price.respond_to?(:currency)
        if price.respond_to?(:recurring) && price.recurring&.respond_to?(:interval)
          subscription_data[:interval] = price.recurring.interval
        end
      end
      
      subscription_data
    rescue Stripe::StripeError => e
      Rails.logger.error "Error fetching subscription info for user #{user.email}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error fetching subscription info for user #{user.email}: #{e.message}"
      nil
    end
  end

  # Health check methods for Docker/monitoring
  def database_healthy?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError => e
    Rails.logger.error "Database health check failed: #{e.message}"
    false
  end

  def redis_healthy?
    return true unless defined?(Redis) # Skip if Redis not configured
    
    Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0').ping == 'PONG'
  rescue StandardError => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    false
  end

  def storage_healthy?
    # Check if storage directory is writable
    storage_path = Rails.root.join('storage')
    storage_path.exist? && storage_path.writable?
  rescue StandardError => e
    Rails.logger.error "Storage health check failed: #{e.message}"
    false
  end
end
