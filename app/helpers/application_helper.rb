module ApplicationHelper
  # Helper to check if user has an active subscription
  def user_has_active_subscription?(user)
    return false unless user&.pro?

    # This is a simple check - for more complex logic,
    # you might want to check with Stripe API
    user.pro?
  end

  # Helper to format subscription status
  def subscription_status_badge(cancel_at_period_end)
    if cancel_at_period_end
      content_tag :span, "Cancelling",
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    else
      content_tag :span, "Active",
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    end
  end
end
