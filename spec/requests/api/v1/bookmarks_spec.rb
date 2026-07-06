require "rails_helper"

RSpec.describe "Api::V1::Bookmarks", type: :request do
  def auth_headers(user)
    token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
    { "Authorization" => "Bearer #{token}" }
  end

  it "saves and lists a recipe" do
    user = create(:user)
    author = create(:user)
    recipe = author.recipes.create!(title: "Save Me", status: "published")

    post "/api/v1/recipes/#{recipe.id}/save", headers: auth_headers(user)
    expect(response).to have_http_status(:created)

    get "/api/v1/me/saved", headers: auth_headers(user)
    expect(JSON.parse(response.body).size).to eq(1)
  end

  it "does not save the same recipe twice" do
    user = create(:user)
    recipe = create(:user).recipes.create!(title: "Once", status: "published")

    post "/api/v1/recipes/#{recipe.id}/save", headers: auth_headers(user)
    post "/api/v1/recipes/#{recipe.id}/save", headers: auth_headers(user)

    expect(user.bookmarks.count).to eq(1)
  end
end
