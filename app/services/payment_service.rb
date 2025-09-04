# frozen_string_literal: true

class PaymentService
  class << self
    def process_successful_payment(session_data, user)
      ActiveRecord::Base.transaction do
        # Check if already processed to prevent duplicate records
        existing_payment = Payment.find_by(stripe_charge_id: session_data[:session_id])
        return { already_processed: true, payment: existing_payment } if existing_payment&.completed?

        if session_data[:payment_status] == "paid"
          # Create payment record only after successful payment
          payment = Payment.create!(
            user: user,
            amount: (session_data[:amount_total] || 0) / 100.0,
            status: "completed",
            currency: session_data[:currency] || "usd",
            stripe_charge_id: session_data[:session_id]
          )

          # Update user role
          user.update!(role: "pro")

          # Clean up cache
          Rails.cache.delete("checkout_session_#{session_data[:session_id]}")

          # Send confirmation email (if UserMailerJob exists)
          begin
            UserMailerJob.perform_later(user.id, "pro_upgrade", payment.id)
          rescue NameError
            Rails.logger.info "UserMailerJob not defined, skipping email"
          end

          { success: true, payment: payment, message: "Welcome to Pro! Your account has been upgraded successfully." }
        else
          { success: false, message: "Payment verification failed. Please contact support." }
        end
      end
    end

    def get_payment_statistics
      Rails.cache.fetch("payments:stats:v2", expires_in: 5.minutes) do
        # Use a single query with proper aggregation
        stats_data = Payment.group(:status).pluck(:status, Arel.sql("COUNT(*)"), Arel.sql("SUM(amount)"))

        stats = {}
        total_count = 0
        completed_revenue = 0

        stats_data.each do |status, count, sum_amount|
          stats[status] = count
          total_count += count
          completed_revenue += sum_amount.to_f if status == "completed"
        end

        {
          total: total_count,
          completed_revenue: completed_revenue,
          pending_count: stats["pending"] || 0,
          failed_count: stats["failed"] || 0,
          completed_count: stats["completed"] || 0
        }
      end
    end

    def get_paginated_payments(page)
      Payment.includes(:user)
             .order(created_at: :desc)
             .page(page)
             .per(20)
    end

    def cancel_user_subscription(user)
      subscription_info = SubscriptionService.get_user_subscription_info(user)

      if subscription_info.nil?
        return { success: false, message: "No active subscription found." }
      end

      # Cancel the subscription at the end of the current billing period
      cancelled_subscription = Stripe::Subscription.update(
        subscription_info[:subscription_id],
        {
          cancel_at_period_end: true,
          metadata: {
            cancelled_by_user: "true",
            cancelled_at: Time.current.to_s
          }
        }
      )

      # Log the cancellation
      Rails.logger.info "Subscription cancelled by user #{user.email}: #{subscription_info[:subscription_id]}"

      # Create a cancellation record (optional - for audit trail)
      Payment.create!(
        user: user,
        amount: 0.01, # Small amount to satisfy validation
        status: "cancelled",
        currency: "usd",
        stripe_charge_id: "cancellation_#{cancelled_subscription.id}",
        error_message: "Subscription cancelled by user"
      )

      # Safely get the end date
      end_date = if cancelled_subscription.respond_to?(:current_period_end) && cancelled_subscription.current_period_end
                   Time.at(cancelled_subscription.current_period_end).strftime("%B %d, %Y")
      else
                   "the end of your current billing period"
      end

      {
        success: true,
        message: "Your subscription has been cancelled and will not renew. You'll continue to have Pro access until #{end_date}."
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error during cancellation: #{e.message}"
      { success: false, message: "Unable to cancel subscription. Please try again or contact support." }
    rescue StandardError => e
      Rails.logger.error "Error during subscription cancellation: #{e.message}"
      { success: false, message: "An unexpected error occurred. Please contact support." }
    end

    def check_rate_limit(request, user)
      rate_limit_key = "payment_#{request.remote_ip}_#{user&.id}"

      current_count = Rails.cache.read(rate_limit_key).to_i
      if current_count >= 10 # 10 payment attempts per hour
        { exceeded: true, message: "Too many payment attempts. Please try again later." }
      else
        Rails.cache.increment(rate_limit_key, 1, expires_in: 1.hour)
        { exceeded: false }
      end
    end
  end
end
