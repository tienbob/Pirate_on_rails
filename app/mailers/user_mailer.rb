class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: 'Welcome to Pirate on Rails!')
  end

  def pro_upgrade_email(user)
    @user = user
    mail(to: @user.email, subject: 'Congratulations on Upgrading to Pro!')
  end
end
