require "test_helper"

class PaymentMailerJobTest < ActiveJob::TestCase
  test "perform sends mail" do
    user = users(:user1) # Use fixture instead of factory

    assert_emails 1 do
      PaymentMailerJob.perform_now(user)
    end
  end
end
