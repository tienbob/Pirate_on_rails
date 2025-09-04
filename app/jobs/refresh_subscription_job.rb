class RefreshSubscriptionJob < ApplicationJob
  queue_as :default

  # Retry logic for transient errors
  retry_on Stripe::RateLimitError, wait: 30.seconds, attempts: 3
  retry_on Stripe::APIConnectionError, wait: 10.seconds, attempts: 5
  retry_on Stripe::APIError, wait: 15.seconds, attempts: 3
  retry_on Timeout::Error, wait: 15.seconds, attempts: 3
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(user_id)
    Rails.logger.info "Starting subscription refresh for user ID: #{user_id}"

    user = User.find_by(id: user_id)
    unless user
      Rails.logger.error "User not found for ID: #{user_id}"
      return
    end

    # Security check: only refresh for pro users
    unless user.pro?
      Rails.logger.warn "Skipping subscription refresh for non-pro user: #{user.email}"
      return
    end

    Rails.logger.info "Refreshing subscription for user: #{user.email}"

    # Get current cached data for fallback
    cache_key = "subscription_info:#{user.id}"
    customer_cache_key = "stripe_customer:#{user.email}"
    cached_data = Rails.cache.read(cache_key)

    Rails.logger.debug "Found cached data: #{cached_data.present?}" if cached_data

    # Clear existing cache to force fresh data
    Rails.cache.delete(cache_key)
    Rails.cache.delete(customer_cache_key)

    # Refresh data
    begin
      Rails.logger.info "Fetching fresh subscription data from Stripe for user: #{user.email}"

      # This will fetch fresh data and cache it
      subscription_info = get_subscription_info_fresh(user)

      if subscription_info
        # Increased cache expiration time to account for potential delays
        Rails.cache.write(cache_key, subscription_info, expires_in: 15.minutes)
        Rails.logger.info "Successfully refreshed and cached subscription data for #{user.email}"
        Rails.logger.debug "Cached subscription info: #{subscription_info.inspect}"
      else
        Rails.logger.warn "No subscription info found for user: #{user.email}"
        # Use dynamic fallback data based on cached data or user's payment history
        fallback_data = generate_dynamic_fallback_data(user, cached_data)
        Rails.cache.write(cache_key, fallback_data, expires_in: 10.minutes)
        Rails.logger.info "Used dynamic fallback data for user: #{user.email}"
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe API error while refreshing subscription for #{user.email}: #{e.message}"
      Rails.logger.error "Stripe error details: #{e.class} - #{e.code}" if e.respond_to?(:code)

      # Use dynamic fallback data on Stripe errors
      fallback_data = generate_dynamic_fallback_data(user, cached_data)
      Rails.cache.write(cache_key, fallback_data, expires_in: 5.minutes)
      raise # Re-raise to trigger retry logic
    rescue => e
      Rails.logger.error "Unexpected error while refreshing subscription for #{user.email}: #{e.message}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join("\n")}"

      # Use dynamic fallback data on unexpected errors
      fallback_data = generate_dynamic_fallback_data(user, cached_data)
      Rails.cache.write(cache_key, fallback_data, expires_in: 5.minutes)
      raise # Re-raise to trigger retry logic
    end
  end

  private

  def get_subscription_info_fresh(user)
    Rails.logger.info "Searching for Stripe customer for user: #{user.email}"

    # Find customer
    customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })
    if customer_search.data.empty?
      Rails.logger.warn "No Stripe customer found for user: #{user.email}"
      return nil
    end

    customer = customer_search.data.first
    Rails.logger.info "Found Stripe customer: #{customer.id} for user: #{user.email}"

    # Cache customer ID for future use with increased expiration
    customer_cache_key = "stripe_customer:#{user.email}"
    Rails.cache.write(customer_cache_key, customer.id, expires_in: 4.hours)

    # Get active subscription
    Rails.logger.info "Fetching active subscriptions for customer: #{customer.id}"
    subscriptions = Stripe::Subscription.list({
      customer: customer.id,
      status: "active",
      limit: 1
    })

    subscription = subscriptions.data.first
    unless subscription
      Rails.logger.warn "No active subscription found for customer: #{customer.id}"
      return nil
    end

    Rails.logger.info "Found active subscription: #{subscription.id} for user: #{user.email}"

    subscription_item = subscription.items.data.first

    # Calculate next billing date safely
    next_billing_date = begin
      Rails.logger.debug "Calculating next billing date for subscription: #{subscription.id}"

      if subscription.respond_to?(:current_period_end) && subscription.current_period_end
        calculated_date = Time.at(subscription.current_period_end)
        Rails.logger.debug "Using subscription current_period_end: #{calculated_date}"
        calculated_date
      elsif subscription_item&.respond_to?(:current_period_end) && subscription_item.current_period_end
        calculated_date = Time.at(subscription_item.current_period_end)
        Rails.logger.debug "Using subscription_item current_period_end: #{calculated_date}"
        calculated_date
      else
        # Fallback calculation
        interval = subscription_item&.price&.recurring&.interval || "month"
        created_time = subscription.created ? Time.at(subscription.created) : Time.current

        Rails.logger.debug "Using fallback calculation with interval: #{interval}, created: #{created_time}"

        case interval
        when "month" then created_time + 1.month
        when "year" then created_time + 1.year
        when "week" then created_time + 1.week
        when "day" then created_time + 1.day
        else 1.month.from_now
        end
      end
    rescue => e
      Rails.logger.error "Error calculating next billing date for subscription #{subscription.id}: #{e.message}"
      1.month.from_now
    end

    subscription_data = {
      subscription_id: subscription.id,
      status: subscription.status,
      amount: (subscription_item&.price&.unit_amount || 999) / 100.0,
      currency: (subscription_item&.price&.currency || "sgd").upcase,
      interval: subscription_item&.price&.recurring&.interval || "month",
      next_billing_date: next_billing_date,
      cancel_at_period_end: subscription.respond_to?(:cancel_at_period_end) ? (subscription.cancel_at_period_end || false) : false,
      cancelled_at: (subscription.respond_to?(:canceled_at) && subscription.canceled_at) ? Time.at(subscription.canceled_at) : nil,
      created: subscription.created ? Time.at(subscription.created) : Time.current
    }

    Rails.logger.info "Successfully extracted subscription data for user: #{user.email}"
    Rails.logger.debug "Subscription data: #{subscription_data.inspect}"

    subscription_data
  end

  # Generate dynamic fallback data based on user's payment history and cached data
  def generate_dynamic_fallback_data(user, cached_data)
    Rails.logger.info "Generating dynamic fallback data for user: #{user.email}"

    # Try to get data from user's payment history
    latest_payment = Payment.where(user: user, status: "completed")
                           .order(created_at: :desc)
                           .first

    if latest_payment
      Rails.logger.info "Using data from latest payment: #{latest_payment.id} for fallback"

      # Extract price information from Stripe if available
      amount = latest_payment.amount || 9.99
      currency = latest_payment.currency&.upcase || "SGD"
    elsif cached_data
      Rails.logger.info "Using cached data for fallback"
      amount = cached_data[:amount] || cached_data["amount"] || 9.99
      currency = cached_data[:currency] || cached_data["currency"] || "SGD"
    else
      Rails.logger.info "Using default fallback values"
      amount = 9.99
      currency = "SGD"
    end

    # Calculate next billing date based on user's subscription start
    next_billing_date = if cached_data && (cached_data[:next_billing_date] || cached_data["next_billing_date"])
                         cached_next = cached_data[:next_billing_date] || cached_data["next_billing_date"]
                         cached_next.is_a?(String) ? Time.parse(cached_next) : cached_next
    elsif latest_payment
                         latest_payment.created_at + 1.month
    else
                         1.month.from_now
    end

    fallback_data = {
      subscription_id: "fallback_data",
      status: "active",
      amount: amount,
      currency: currency,
      interval: "month",
      next_billing_date: next_billing_date,
      cancel_at_period_end: false,
      cancelled_at: nil,
      created: latest_payment&.created_at || user.created_at || Time.current
    }

    Rails.logger.info "Generated fallback data for user: #{user.email} - Amount: #{amount} #{currency}"

    fallback_data
  end
end
