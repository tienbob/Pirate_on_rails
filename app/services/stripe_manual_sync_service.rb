class StripeManualSyncService
  def self.sync_user_subscription(user)
    Rails.logger.info "Starting manual sync for user: #{user.email}"
    
    begin
      # Find Stripe customer by email
      customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })
      
      if customer_search.data.empty?
        Rails.logger.warn "No Stripe customer found for user: #{user.email}"
        return { success: false, message: "No Stripe customer found" }
      end
      
      customer = customer_search.data.first
      Rails.logger.info "Found Stripe customer: #{customer.id}"
      
      # Get active subscriptions
      subscriptions = Stripe::Subscription.list({
        customer: customer.id,
        status: 'all', # Get all statuses to see the full picture
        limit: 10
      })
      
      Rails.logger.info "Found #{subscriptions.data.length} subscriptions"
      
      subscriptions.data.each do |subscription|
        Rails.logger.info "Subscription #{subscription.id}: status=#{subscription.status}, cancel_at_period_end=#{subscription.cancel_at_period_end}"
        
        # Create payment record for current subscription status
        status = case subscription.status
                 when 'active'
                   subscription.cancel_at_period_end ? 'cancelling' : 'active'
                 when 'canceled'
                   'cancelled'
                 else
                   subscription.status
                 end
        
        # Check if we already have a recent record for this subscription
        existing_payment = Payment.where(
          user: user,
          stripe_charge_id: "manual_sync_#{subscription.id}"
        ).where('created_at > ?', 1.hour.ago).first
        
        unless existing_payment
          Payment.create!(
            user: user,
            amount: 0.01,
            currency: 'usd',
            status: status,
            stripe_charge_id: "manual_sync_#{subscription.id}",
            metadata: {
              event_type: 'manual_sync',
              subscription_id: subscription.id,
              subscription_status: subscription.status,
              cancel_at_period_end: subscription.cancel_at_period_end,
              current_period_end: subscription.current_period_end&.to_i,
              synced_at: Time.current
            }.to_json
          )
          Rails.logger.info "Created payment record with status: #{status}"
        end
        
        # Update user role based on subscription
        if subscription.status == 'active'
          user.update!(role: 'pro')
          Rails.logger.info "Updated user role to pro"
        elsif subscription.status == 'canceled'
          user.update!(role: 'free')
          Rails.logger.info "Updated user role to free"
        end
      end
      
      # Clear cache
      Rails.cache.delete("subscription_info:#{user.id}")
      Rails.cache.delete("stripe_customer:#{user.email}")
      Rails.cache.delete("user_#{user.id}_checkout_session")
      
      { success: true, message: "Sync completed successfully" }
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error during manual sync: #{e.message}"
      { success: false, message: "Stripe error: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error "Unexpected error during manual sync: #{e.message}"
      { success: false, message: "Unexpected error: #{e.message}" }
    end
  end
end
