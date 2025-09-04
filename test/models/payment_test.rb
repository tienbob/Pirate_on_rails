require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "validations" do
    payment = Payment.new
    assert_not payment.valid?, "Payment should be invalid without required attributes"

    # Add specific validation tests
    assert payment.errors[:amount].any?, "Should have error on amount"
    # Add other required field validations as needed
  end

  test "formatted_amount" do
    p = build(:payment, amount: 12.5)
    assert_equal "$12.50", p.formatted_amount
  end

  test "state helpers" do
    p = build(:payment, status: 'completed')
    assert p.completed?
    p.status = 'failed'
    assert p.failed?
  end
end
