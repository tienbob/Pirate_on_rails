class PaymentMailerJob < ApplicationJob
  queue_as :default

  def perform(user_id, payment_id)
    user = User.find_by(id: user_id)
    payment = Payment.find_by(id: payment_id)
    PaymentMailer.with(user: user, payment: payment).pro_upgrade.deliver_later
  end
end
