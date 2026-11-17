FactoryBot.define do
  factory :view_analytic do
    association :user
    association :movie
    viewed_at { Time.current }
    watch_duration { 120 }
    completed_viewing { false }
  end
end
