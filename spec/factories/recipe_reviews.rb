FactoryBot.define do
  factory :recipe_review do
    user { nil }
    recipe { nil }
    rating { 1 }
    body { "MyText" }
  end
end
