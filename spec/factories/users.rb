FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Cook #{n}" }
    sequence(:handle) { |n| "cook#{n}" }
    sequence(:email) { |n| "cook#{n}@test.com" }
    password { "password123" }
  end
end
