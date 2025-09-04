require "test_helper"

class PaymentMailerJobTest < ActiveJob::TestCase
  test "perform sends mail" do
    user = create(:user)
    payment = create(:payment, user: user)

    assert_emails 1 do
      PaymentMailerJob.perform_now(user.id, payment.id)
    end
  end
end
