# frozen_string_literal: true

class StripeWebhookHandler
  def self.process(event)
    Rails.logger.info "Processing Stripe webhook event: #{event.type} for #{event.data.object.try(:customer) || 'unknown customer'}"
    
    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event.data.object)
    when 'customer.subscription.created'
      handle_subscription_created(event.data.object)
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'invoice.payment_succeeded'
      handle_payment_succeeded(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    else
      Rails.logger.info "Unhandled webhook event: #{event.type}"
    end
  end

  def self.handle_checkout_completed(session)
    user = User.find_by(id: session.metadata['user_id'])
    return unless user

    # Logic for handling checkout completion
    Rails.logger.info "Checkout completed for user: #{user.id}"
  end

  def self.handle_subscription_created(subscription)
    user = find_user_by_stripe_customer(subscription.customer)
    return unless user

    # Create payment record for subscription creation
    Payment.create!(
      user: user,
      amount: 0.01, # Nominal amount for subscription events
      currency: 'usd',
      status: 'completed',
      stripe_charge_id: "subscription_#{subscription.id}",
      metadata: { event_type: 'subscription_created', subscription_id: subscription.id }.to_json
    )

    # Update user's role
    user.update!(role: 'pro')
    
    # Clear cached subscription data
    clear_user_subscription_cache(user)
    
    Rails.logger.info "Subscription created for user: #{user.id}"
  end

  def self.handle_subscription_updated(subscription)
    user = find_user_by_stripe_customer(subscription.customer)
    return unless user

    # Create payment record for subscription update
    status = subscription.cancel_at_period_end ? 'cancelling' : 'active'
    
    Payment.create!(
      user: user,
      amount: 0.01, # Nominal amount for subscription events
      currency: 'usd',
      status: status,
      stripe_charge_id: "subscription_update_#{subscription.id}_#{Time.current.to_i}",
      metadata: { 
        event_type: 'subscription_updated', 
        subscription_id: subscription.id,
        cancel_at_period_end: subscription.cancel_at_period_end,
        current_period_end: subscription.current_period_end
      }.to_json
    )

    # Update user's role based on subscription status
    if subscription.cancel_at_period_end
      # Keep pro until period ends, but mark as cancelling
      user.update!(role: 'pro') # Keep pro access until period ends
      Rails.logger.info "User #{user.id} subscription is set to cancel at period end."
    else
      user.update!(role: 'pro')
      Rails.logger.info "User #{user.id} subscription is active."
    end
    
    # Clear cached subscription data
    clear_user_subscription_cache(user)
  end

  def self.handle_payment_succeeded(invoice)
    user = find_user_by_stripe_customer(invoice.customer)
    return unless user

    # Create payment record for successful payment
    Payment.create!(
      user: user,
      amount: invoice.amount_paid / 100.0, # Convert from cents
      currency: invoice.currency,
      status: 'completed',
      stripe_charge_id: "invoice_#{invoice.id}",
      metadata: { 
        event_type: 'payment_succeeded', 
        invoice_id: invoice.id,
        subscription_id: invoice.subscription
      }.to_json
    )

    # Update user's role to pro
    user.update!(role: 'pro')
    
    # Clear cached subscription data
    clear_user_subscription_cache(user)
    
    Rails.logger.info "Payment succeeded for user: #{user.id}"
  end

  def self.handle_subscription_deleted(subscription)
    user = find_user_by_stripe_customer(subscription.customer)
    return unless user

    # Create payment record for subscription deletion
    Payment.create!(
      user: user,
      amount: 0.01, # Nominal amount for subscription events
      currency: 'usd',
      status: 'cancelled',
      stripe_charge_id: "cancellation_#{subscription.id}",
      error_message: 'Subscription cancelled by user',
      metadata: { event_type: 'subscription_deleted', subscription_id: subscription.id }.to_json
    )

    # Update user's role to free
    user.update!(role: 'free')
    
    # Clear cached subscription data
    clear_user_subscription_cache(user)
    
    Rails.logger.info "User #{user.id} subscription has been cancelled."
  end

  private

  def self.find_user_by_stripe_customer(customer_id)
    # First try to find by email since we don't have stripe_customer_id field
    customer = Stripe::Customer.retrieve(customer_id)
    User.find_by(email: customer.email)
  rescue Stripe::StripeError => e
    Rails.logger.error "Error retrieving Stripe customer #{customer_id}: #{e.message}"
    nil
  end

  def self.clear_user_subscription_cache(user)
    # Clear all subscription-related cache keys for the user
    Rails.cache.delete("subscription_info:#{user.id}")
    Rails.cache.delete("stripe_customer:#{user.email}")
    Rails.cache.delete("user_#{user.id}_checkout_session")
    
    Rails.logger.info "Cleared subscription cache for user: #{user.id}"
  end
end
