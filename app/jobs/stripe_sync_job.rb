class StripeSyncJob < ApplicationJob
  queue_as :default

  def perform
    # Fetch all subscriptions from Stripe
    Stripe::Subscription.list.each do |subscription|
      # Find the local subscription by Stripe ID
      local_subscription = Subscription.find_by(stripe_id: subscription.id)

      if local_subscription
        # Update local subscription details
        local_subscription.update(
          status: subscription.status,
          current_period_end: Time.at(subscription.current_period_end),
          current_period_start: Time.at(subscription.current_period_start)
        )
      else
        # Optionally, log or handle missing subscriptions
        Rails.logger.warn("Subscription with Stripe ID #{subscription.id} not found locally.")
      end
    end
  end
end
