FactoryBot.define do
  factory :stripe_event do
    sequence(:event_id) { |n| "evt_#{n}" }
  end
end
