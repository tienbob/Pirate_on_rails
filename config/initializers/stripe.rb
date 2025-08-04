# Stripe configuration
Rails.application.configure do
  # Set Stripe API key from credentials
  if Rails.application.credentials.stripe
    Stripe.api_key = Rails.application.credentials.stripe[:secret_key]
    Stripe.api_version = '2023-10-16' # Use a specific API version for consistency
  elsif ENV['STRIPE_SERVER_API_KEY']
    Stripe.api_key = ENV['STRIPE_SERVER_API_KEY']
  else
    Rails.logger.warn "Stripe credentials not found. Payment functionality will be disabled."
  end
end

# Stripe webhook signature verification
module StripeHelper
  WEBHOOK_SECRET = Rails.application.credentials.dig(:stripe, :webhook_secret) || ENV['STRIPE_WEBHOOK_SECRET']
  
  def self.verify_webhook(payload, signature)
    return false unless WEBHOOK_SECRET
    
    begin
      Stripe::Webhook.construct_event(payload, signature, WEBHOOK_SECRET)
      true
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      false
    end
  end
  
  def self.create_customer(user)
    Stripe::Customer.create(
      email: user.email,
      name: user.name,
      metadata: {
        user_id: user.id,
        created_at: user.created_at.iso8601
      }
    )
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to create Stripe customer: #{e.message}"
    nil
  end
  
  def self.retrieve_safe(stripe_id, type = :customer)
    case type
    when :customer
      Stripe::Customer.retrieve(stripe_id)
    when :session
      Stripe::Checkout::Session.retrieve(stripe_id)
    when :subscription
      Stripe::Subscription.retrieve(stripe_id)
    else
      raise ArgumentError, "Unknown Stripe object type: #{type}"
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to retrieve Stripe #{type}: #{e.message}"
    nil
  end
end

# Price configuration
STRIPE_PRICES = {
  monthly: ENV.fetch('STRIPE_MONTHLY_PRICE_ID', 'price_monthly_default'),
  yearly: ENV.fetch('STRIPE_YEARLY_PRICE_ID', 'price_yearly_default')
}.freeze
