require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "validations" do
    payment = build(:payment)
    assert payment.valid?
    invalid = Payment.new
    assert_not invalid.valid?
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
