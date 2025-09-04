FactoryBot.define do
  factory :chat do
    association :user
    user_message { 'Hello' }
    ai_response { '' }
  end
end
