# frozen_string_literal: true

class SubscriptionService
  class << self
    def get_user_subscription_info(user)
      return nil unless user&.pro?

      # Try to use cached Stripe customer ID first
      customer_cache_key = "stripe_customer:#{user.email}"
      customer_id = Rails.cache.fetch(customer_cache_key, expires_in: 1.hour) do
        customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })
        customer_search.data.empty? ? nil : customer_search.data.first.id
      end

      return nil unless customer_id

      begin
        # Get subscriptions with cached customer ID
        subscriptions = Stripe::Subscription.list({
          customer: customer_id,
          status: 'active',  # Only get active subscriptions for faster response
          limit: 1  # We only need the first active one
        })

        subscription = subscriptions.data.first
        return nil unless subscription

        # Use helper method to safely extract subscription data
        extract_subscription_data(subscription)
        
      rescue Stripe::StripeError => e
        Rails.logger.error "Error fetching subscription info for user #{user.email}: #{e.message}"
        fallback_subscription_data('error_loading')
      rescue NoMethodError => e
        Rails.logger.error "NoMethodError in subscription info for user #{user.email}: #{e.message}"
        fallback_subscription_data('method_error')
      rescue StandardError => e
        Rails.logger.error "Unexpected error fetching subscription info for user #{user.email}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
        fallback_subscription_data('unexpected_error')
      end
    end

    def get_subscription_with_fallback(user)
      # Check if we have cached subscription info (increased expiration time)
      cache_key = "subscription_info:#{user.id}"
      subscription_info = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        get_user_subscription_info(user)
      end
      
      # Schedule background refresh if cache is older than 5 minutes (increased threshold)
      schedule_background_refresh(user)
      
      if subscription_info.nil?
        # Use dynamic fallback data based on user's payment history
        generate_dynamic_fallback_data(user)
      else
        subscription_info
      end
    end

    def sync_user_with_stripe(user)
      return unless user

      ActiveRecord::Base.transaction do
        customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })
        
        if customer_search.data.empty?
          # No Stripe customer found, ensure user is free
          user.update!(role: 'free') if user.pro?
          return
        end

        customer = customer_search.data.first
        subscriptions = Stripe::Subscription.list({
          customer: customer.id,
          status: 'all',
          limit: 10
        })

        # Find active subscription
        active_subscription = subscriptions.data.find { |sub| %w[active trialing].include?(sub.status) }
        
        if active_subscription
          # User has active subscription, should be pro
          user.update!(role: 'pro') unless user.pro?
        else
          # No active subscription, should be free
          user.update!(role: 'free') if user.pro?
        end
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Error syncing user #{user.email} with Stripe: #{e.message}"
    end

    private

    def schedule_background_refresh(user)
      last_refresh_key = "last_refresh:#{user.id}"
      last_refresh = Rails.cache.read(last_refresh_key)
      
      if last_refresh.nil? || last_refresh < 5.minutes.ago
        RefreshSubscriptionJob.perform_later(user.id)
        # Increased cache expiration for last refresh tracking
        Rails.cache.write(last_refresh_key, Time.current, expires_in: 15.minutes)
        Rails.logger.info "Scheduled background subscription refresh for user: #{user.email}"
      end
    end

    def generate_dynamic_fallback_data(user)
      latest_payment = Payment.where(user: user, status: 'completed')
                             .order(created_at: :desc)
                             .first
      
      # Dynamic fallback using user's actual payment data
      {
        status: 'active',
        subscription_id: 'loading...',
        next_billing_date: latest_payment ? latest_payment.created_at + 1.month : 1.month.from_now,
        amount: latest_payment&.amount || 9.99,
        currency: latest_payment&.currency&.upcase || 'SGD',
        interval: 'month'
      }
    end

    def extract_subscription_data(subscription)
      subscription_item = subscription.items.data.first
      
      # Safely get next billing date
      next_billing_date = calculate_next_billing_date(subscription, subscription_item)
      
      {
        subscription_id: subscription.id,
        status: subscription.status,
        amount: safe_amount(subscription_item),
        currency: safe_currency(subscription_item),
        interval: safe_interval(subscription_item),
        next_billing_date: next_billing_date,
        cancel_at_period_end: safe_boolean(subscription, :cancel_at_period_end),
        cancelled_at: safe_timestamp(subscription, :canceled_at),
        created: safe_timestamp(subscription, :created, Time.current)
      }
    end

    def calculate_next_billing_date(subscription, subscription_item)
      # Try multiple approaches to get the billing date
      if subscription.respond_to?(:current_period_end) && subscription.current_period_end
        return Time.at(subscription.current_period_end)
      end
      
      if subscription_item&.respond_to?(:current_period_end) && subscription_item.current_period_end
        return Time.at(subscription_item.current_period_end)
      end
      
      # Fallback: calculate based on creation time and interval
      interval = safe_interval(subscription_item)
      created_time = safe_timestamp(subscription, :created, Time.current)
      
      case interval
      when 'month' then created_time + 1.month
      when 'year' then created_time + 1.year
      when 'week' then created_time + 1.week
      when 'day' then created_time + 1.day
      else 1.month.from_now
      end
    rescue => e
      Rails.logger.error "Error calculating next billing date: #{e.message}"
      1.month.from_now
    end

    def safe_amount(subscription_item)
      (subscription_item&.price&.unit_amount || 999) / 100.0
    end

    def safe_currency(subscription_item)
      (subscription_item&.price&.currency || 'sgd').upcase
    end

    def safe_interval(subscription_item)
      subscription_item&.price&.recurring&.interval || 'month'
    end

    def safe_boolean(object, method, default = false)
      object.respond_to?(method) ? (object.send(method) || default) : default
    end

    def safe_timestamp(object, method, default = nil)
      if object.respond_to?(method) && object.send(method)
        Time.at(object.send(method))
      else
        default
      end
    end

    def fallback_subscription_data(error_type = 'unknown')
      {
        subscription_id: error_type,
        status: 'active',
        amount: 9.99,
        currency: 'SGD',
        interval: 'month',
        next_billing_date: 1.month.from_now,
        cancel_at_period_end: false,
        cancelled_at: nil,
        created: Time.current
      }
    end
  end
end
