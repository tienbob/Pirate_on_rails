class UserMailerJob < ApplicationJob
  queue_as :default

  def perform(args)
    user_id = args[:user_id]
    email_type = args[:email_type]
    payment_id = args[:payment_id]
    user = User.find_by(id: user_id)

    case email_type
    when "welcome"
      UserMailer.welcome_email(user).deliver_later
    when "pro_upgrade"
      UserMailer.pro_upgrade_email(user).deliver_later
    else
      Rails.logger.warn "Unknown email type: \\#{email_type}"
    end
  end
end
