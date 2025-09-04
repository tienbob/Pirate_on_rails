require "test_helper"

class PaymentEventTest < ActiveSupport::TestCase
  test "validates event_type inclusion" do
    payment = create(:payment)
    pe = build(:payment_event, payment: payment, event_type: 'created', event_data: { a: 1 })
    assert pe.valid?
    invalid = build(:payment_event, payment: payment, event_type: 'not_a_type', event_data: {})
    assert_not invalid.valid?
  end

  test "log_event creates record" do
    payment = create(:payment)
    assert_difference 'PaymentEvent.count', 1 do
      PaymentEvent.log_event(payment, 'created', { foo: 'bar' })
    end
  end
end
