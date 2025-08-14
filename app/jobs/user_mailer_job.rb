class UserMailerJob < ApplicationJob
  queue_as :default

  def perform(user_id, email_type, payment_id = nil)
    user = User.find(user_id)

    case email_type
    when 'welcome'
      UserMailer.welcome_email(user).deliver_now
    when 'pro_upgrade'
      UserMailer.pro_upgrade_email(user).deliver_now
    else
      Rails.logger.warn "Unknown email type: \\#{email_type}"
    end
  end
end
