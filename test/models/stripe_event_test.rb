require "test_helper"

class StripeEventTest < ActiveSupport::TestCase
  test "requires event_id" do
    se = build(:stripe_event)
    assert se.valid?
    se.event_id = nil
    assert_not se.valid?
  end
end
