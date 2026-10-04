require "rails_helper"

RSpec.describe RecipeReview, type: :model do
  it "rejects ratings outside one through five" do
    user = create(:user)
    recipe = user.recipes.create!(title: "Soup")
    review = recipe.recipe_reviews.new(user: user, body: "Great", rating: 6)
    expect(review).not_to be_valid
    review.rating = 5
    expect(review).to be_valid
  end

  it "prevents duplicate reviews by the same cook" do
    user = create(:user)
    recipe = user.recipes.create!(title: "Soup")
    recipe.recipe_reviews.create!(user: user, body: "Great", rating: 5)
    expect(recipe.recipe_reviews.new(user: user, body: "Again", rating: 4)).not_to be_valid
  end
end
