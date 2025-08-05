class RefreshSubscriptionJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.pro?

    Rails.logger.info "Background refresh for user #{user.email}"
    
    # Clear existing cache
    cache_key = "subscription_info:#{user.id}"
    customer_cache_key = "stripe_customer:#{user.email}"
    
    Rails.cache.delete(cache_key)
    Rails.cache.delete(customer_cache_key)
    
    # Refresh data
    begin
      # This will fetch fresh data and cache it
      subscription_info = get_subscription_info_fresh(user)
      
      if subscription_info
        Rails.cache.write(cache_key, subscription_info, expires_in: 5.minutes)
        Rails.logger.info "Refreshed subscription cache for #{user.email}"
      end
    rescue => e
      Rails.logger.error "Failed to refresh subscription for #{user.email}: #{e.message}"
    end
  end

  private

  def get_subscription_info_fresh(user)
    # Find customer
    customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })
    return nil if customer_search.data.empty?

    customer = customer_search.data.first
    
    # Cache customer ID for future use
    customer_cache_key = "stripe_customer:#{user.email}"
    Rails.cache.write(customer_cache_key, customer.id, expires_in: 1.hour)
    
    # Get active subscription
    subscriptions = Stripe::Subscription.list({
      customer: customer.id,
      status: 'active',
      limit: 1
    })

    subscription = subscriptions.data.first
    return nil unless subscription

    subscription_item = subscription.items.data.first
    
    # Calculate next billing date safely
    next_billing_date = begin
      if subscription.respond_to?(:current_period_end) && subscription.current_period_end
        Time.at(subscription.current_period_end)
      elsif subscription_item&.respond_to?(:current_period_end) && subscription_item.current_period_end
        Time.at(subscription_item.current_period_end)
      else
        # Fallback calculation
        interval = subscription_item&.price&.recurring&.interval || 'month'
        created_time = subscription.created ? Time.at(subscription.created) : Time.current
        
        case interval
        when 'month' then created_time + 1.month
        when 'year' then created_time + 1.year
        when 'week' then created_time + 1.week
        when 'day' then created_time + 1.day
        else 1.month.from_now
        end
      end
    rescue => e
      Rails.logger.error "Error calculating next billing date: #{e.message}"
      1.month.from_now
    end
    
    {
      subscription_id: subscription.id,
      status: subscription.status,
      amount: (subscription_item&.price&.unit_amount || 999) / 100.0,
      currency: (subscription_item&.price&.currency || 'sgd').upcase,
      interval: subscription_item&.price&.recurring&.interval || 'month',
      next_billing_date: next_billing_date,
      cancel_at_period_end: subscription.respond_to?(:cancel_at_period_end) ? (subscription.cancel_at_period_end || false) : false,
      cancelled_at: (subscription.respond_to?(:canceled_at) && subscription.canceled_at) ? Time.at(subscription.canceled_at) : nil,
      created: subscription.created ? Time.at(subscription.created) : Time.current
    }
  end
end
