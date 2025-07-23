class PaymentMailerJob < ApplicationJob
  queue_as :default

  def perform(user_id, payment_id)
    user = User.find(user_id)
    payment = Payment.find(payment_id)
    PaymentMailer.with(user: user, payment: payment).pro_upgrade.deliver_now
  end
end
