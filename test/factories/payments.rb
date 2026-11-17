FactoryBot.define do
  factory :payment do
    association :user
    amount { 9.99 }
    status { "processing" }
    currency { "usd" }
  end
end
