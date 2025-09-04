class PaymentMailer < ApplicationMailer
  def pro_upgrade
    @user = params[:user]
    @payment = params[:payment]
    mail(to: @user.email, subject: "Your Pro Subscription is Active!")
  end
end
