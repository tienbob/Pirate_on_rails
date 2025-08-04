class PaymentProcessorJob < ApplicationJob
  queue_as :critical

  def perform(payment_id, action)
    payment = Payment.find(payment_id)
    
    case action
    when 'process_upgrade'
      process_user_upgrade(payment)
    when 'send_receipt'
      send_payment_receipt(payment)
    when 'verify_payment'
      verify_stripe_payment(payment)
    end
  rescue StandardError => e
    Rails.logger.error "PaymentProcessorJob failed: #{e.message}"
    payment&.mark_as_failed!(e.message)
  end

  private

  def process_user_upgrade(payment)
    return unless payment.completed?
    
    user = payment.user
    return if user.pro?
    
    ActiveRecord::Base.transaction do
      user.update!(role: 'pro')
      UserMailerJob.perform_later(user.id, 'pro_upgrade', payment.id)
      Rails.logger.info "User #{user.email} upgraded to pro via payment #{payment.id}"
    end
  end

  def send_payment_receipt(payment)
    UserMailerJob.perform_later(payment.user_id, 'payment_receipt', payment.id)
  end

  def verify_stripe_payment(payment)
    return unless payment.stripe_charge_id
    
    begin
      if payment.stripe_charge_id.start_with?('cs_')
        # Checkout session
        session = Stripe::Checkout::Session.retrieve(payment.stripe_charge_id)
        if session.payment_status == 'paid'
          payment.mark_as_completed!
        else
          payment.mark_as_failed!("Payment not completed in Stripe")
        end
      else
        # Direct charge or subscription
        charge = Stripe::Charge.retrieve(payment.stripe_charge_id)
        if charge.paid
          payment.mark_as_completed!
        else
          payment.mark_as_failed!("Charge not paid in Stripe")
        end
      end
    rescue Stripe::StripeError => e
      payment.mark_as_failed!("Stripe verification failed: #{e.message}")
    end
  end
end
