FactoryBot.define do
  factory :movie_tag do
    association :movie
    association :tag
  end
end
