FactoryBot.define do
  factory :payment do
    user { nil }
    amount { 1 }
    currency { "MyString" }
    status { "MyString" }
    stripe_charge_id { "MyString" }
    error_message { "MyText" }
  end
end
