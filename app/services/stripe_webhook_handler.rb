# frozen_string_literal: true

class StripeWebhookHandler
  def self.process(event)
    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event.data.object)
    when 'customer.subscription.created'
      handle_subscription_created(event.data.object)
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'invoice.payment_succeeded'
      handle_payment_succeeded(event.data.object)
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
    user = User.find_by(stripe_customer_id: subscription.customer)
    return unless user

    # Logic for handling subscription creation
    Rails.logger.info "Subscription created for user: #{user.id}"
  end

  def self.handle_subscription_updated(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
    return unless user

    # Logic for handling subscription updates
    Rails.logger.info "Subscription updated for user: #{user.id}"
  end

  def self.handle_payment_succeeded(invoice)
    user = User.find_by(stripe_customer_id: invoice.customer)
    return unless user

    # Logic for handling successful payments
    Rails.logger.info "Payment succeeded for user: #{user.id}"
  end
end
