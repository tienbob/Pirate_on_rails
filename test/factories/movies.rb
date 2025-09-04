FactoryBot.define do
  factory :movie do
    sequence(:title) { |n| "Movie #{n}" }
    description { 'A' * 20 }
    release_date { Date.today }
    is_pro { false }
    video_file { 'file.mp4' }
    association :series
  end
end
