require "rails_helper"

RSpec.describe "Api::V1::Recipes", type: :request do
  # helper: sign a token for a user, like your ApplicationController does
  def token_for(user)
    JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{token_for(user)}" }
  end

  describe "GET /api/v1/recipes" do
    it "lists recipes without auth" do
      user = create(:user)
      user.recipes.create!(title: "Test Soup", status: "published")

      get "/api/v1/recipes"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe "POST /api/v1/recipes" do
    it "creates a recipe when logged in" do
      user = create(:user)

      post "/api/v1/recipes",
        params: { title: "New Dish", difficulty: "Easy" },
        headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["title"]).to eq("New Dish")
    end

    it "rejects creation without a token" do
      post "/api/v1/recipes", params: { title: "Nope" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a recipe with no title" do
      user = create(:user)
      post "/api/v1/recipes", params: { difficulty: "Easy" }, headers: auth_headers(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/recipes/:id" do
    it "stops a user deleting someone else's recipe" do
      owner = create(:user)
      other = create(:user)
      recipe = owner.recipes.create!(title: "Mine", status: "published")

      delete "/api/v1/recipes/#{recipe.id}", headers: auth_headers(other)

      expect(response).to have_http_status(:forbidden)
      expect(Recipe.exists?(recipe.id)).to be true
    end
  end
end
