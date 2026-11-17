FactoryBot.define do
  factory :payment_event do
    association :payment
    event_type { "created" }
    event_data { { foo: "bar" } }
    source { "system" }
  end
end
