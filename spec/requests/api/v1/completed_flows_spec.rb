require "rails_helper"

RSpec.describe "Completed TasteBite flows", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:owner) { create(:user) }
  let(:viewer) { create(:user) }
  let(:recipe) { owner.recipes.create!(title: "Soup", status: "published", difficulty: "Easy", cover_image_url: "https://example.com/soup.jpg", servings: 2) }
  def headers(user)
    token = JWT.encode({ user_id: user.id, version: user.token_version, exp: 1.hour.from_now.to_i }, Rails.application.secret_key_base, "HS256")
    { "Authorization" => "Bearer #{token}" }
  end
  def json
    JSON.parse(response.body)
  end

  it "normalizes account identifiers and allows login" do
    post "/api/v1/auth/signup", params: { name: "Cook", handle: "Mixed_Cook", email: " Mixed@example.com ", password: "password123" }
    expect(response).to have_http_status(:created)
    expect(json["user"]["handle"]).to eq("mixed_cook")
    post "/api/v1/auth/login", params: { email: " MIXED@example.com ", password: "password123" }
    expect(response).to have_http_status(:ok)
  end

  it "rejects a short signup password" do
    post "/api/v1/auth/signup", params: { name: "Cook", handle: "cook", email: "cook@example.com", password: "short" }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "sends a reset email without exposing account existence, expires tokens and invalidates sessions" do
    old_headers = headers(owner)
    ActionMailer::Base.deliveries.clear
    post "/api/v1/auth/forgot-password", params: { email: owner.email }
    expect(response).to have_http_status(:ok)
    message = json
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([owner.email])
    expect(mail.body.to_s).to include("/reset-password?token=")
    post "/api/v1/auth/forgot-password", params: { email: "unknown@example.com" }
    expect(json).to eq(message)
    expect(ActionMailer::Base.deliveries.length).to eq(1)
    token = owner.generate_token_for(:password_reset)
    travel 31.minutes do
      post "/api/v1/auth/reset-password", params: { token: token, password: "newpassword123", password_confirmation: "newpassword123" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
    post "/api/v1/auth/reset-password", params: { token: token, password: "newpassword123", password_confirmation: "newpassword123" }
    expect(response).to have_http_status(:ok)
    get "/api/v1/me", headers: old_headers
    expect(response).to have_http_status(:unauthorized)
    post "/api/v1/auth/reset-password", params: { token: token, password: "anotherpassword123" }
    expect(response).to have_http_status(:unprocessable_entity)
    post "/api/v1/auth/login", params: { email: owner.email, password: "newpassword123" }
    expect(response).to have_http_status(:ok)
  end

  it "rejects invalid reset tokens and mismatching confirmation" do
    post "/api/v1/auth/reset-password", params: { token: "invalid", password: "newpassword123" }
    expect(response).to have_http_status(:unprocessable_entity)
    post "/api/v1/auth/reset-password", params: { token: owner.generate_token_for(:password_reset), password: "newpassword123", password_confirmation: "different" }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "keeps drafts private across list, detail, discovery, profile, saves and reviews" do
    draft = owner.recipes.create!(title: "Secret draft", status: "draft")
    ["/api/v1/recipes", "/api/v1/explore/trending"].each do |path|
      get path, headers: headers(viewer)
      expect(json.map { |item| item["id"] }).not_to include(draft.id)
    end
    get "/api/v1/search", params: { q: "Secret draft" }, headers: headers(viewer)
    expect(json["results"]).to be_empty
    get "/api/v1/users/#{owner.handle}", headers: headers(viewer)
    expect(json["recipes"]).to be_empty
    ["/api/v1/recipes/#{draft.id}", "/api/v1/recipes/#{draft.id}/reviews"].each do |path|
      get path, headers: headers(viewer)
      expect(response).to have_http_status(:not_found)
    end
    post "/api/v1/recipes/#{draft.id}/save", headers: headers(viewer)
    expect(response).to have_http_status(:not_found)
    get "/api/v1/recipes/#{draft.id}", headers: headers(owner)
    expect(response).to have_http_status(:ok)
  end

  it "updates nested rows and deletes removed ingredients/steps without duplicating existing rows" do
    ingredient = recipe.recipe_ingredients.create!(name: "Salt", quantity: "1", unit: "tsp", position: 1)
    removed = recipe.recipe_ingredients.create!(name: "Pepper", position: 2)
    step = recipe.recipe_steps.create!(instruction: "Boil", position: 1)
    patch "/api/v1/recipes/#{recipe.id}", headers: headers(owner), params: {
      title: "Better soup", recipe_ingredients_attributes: [{ id: ingredient.id, quantity: "2" }, { id: removed.id, _destroy: true }, { name: "Water", position: 2 }],
      recipe_steps_attributes: [{ id: step.id, instruction: "Simmer" }]
    }, as: :json
    expect(response).to have_http_status(:ok)
    expect(recipe.reload.recipe_ingredients.count).to eq(2), response.body
    expect(ingredient.reload.quantity).to eq("2")
    expect(step.reload.instruction).to eq("Simmer")
    expect(RecipeIngredient.exists?(removed.id)).to be(false)
  end

  it "forbids edits by another user" do
    patch "/api/v1/recipes/#{recipe.id}", params: { title: "Stolen" }, headers: headers(viewer)
    expect(response).to have_http_status(:forbidden)
    expect(recipe.reload.title).to eq("Soup")
  end

  it "keeps image attachments when editing and adding gallery photos" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/pixel.png"), "image/png")
    post "/api/v1/recipes", headers: headers(owner), params: { title: "Photo soup", cover_image: file, photos: [file] }
    expect(response).to have_http_status(:created)
    id = json["id"]
    photo_ids = json["photo_signed_ids"]
    expect(json["cover_image_url"]).to be_present
    patch "/api/v1/recipes/#{id}", headers: headers(owner), params: { title: "Updated soup", photos: [*photo_ids, file] }
    expect(response).to have_http_status(:ok)
    expect(Recipe.find(id).photos.count).to eq(2)
    expect(Recipe.find(id).cover_image).to be_attached
  end

  it "deletes a recipe with dependencies while preserving its community post" do
    post_record = owner.posts.create!(caption: "Dinner", recipe: recipe)
    plan = owner.meal_plans.create!(week_start_date: "2026-10-05")
    entry = plan.meal_plan_entries.create!(recipe: recipe, date: "2026-10-05", meal_type: "dinner")
    viewer.bookmarks.create!(recipe: recipe)
    recipe.recipe_reviews.create!(user: viewer, body: "Great", rating: 5)
    delete "/api/v1/recipes/#{recipe.id}", headers: headers(owner)
    expect(response).to have_http_status(:no_content)
    expect(post_record.reload.recipe_id).to be_nil
    expect(MealPlanEntry.exists?(entry.id)).to be(false)
  end

  it "returns saved state and images on every recipe surface and supports unsaving" do
    post "/api/v1/recipes/#{recipe.id}/save", headers: headers(viewer)
    ["/api/v1/recipes", "/api/v1/explore/trending", "/api/v1/me/saved"].each do |path|
      get path, headers: headers(viewer)
      item = json.find { |row| row["id"] == recipe.id }
      expect(item["saved"]).to be(true)
      expect(item["cover_image_url"]).to eq(recipe.cover_image_url)
    end
    delete "/api/v1/recipes/#{recipe.id}/save", headers: headers(viewer)
    get "/api/v1/me/saved", headers: headers(viewer)
    expect(json).to be_empty
  end

  it "creates and updates one review per user, recomputes ratings and notifies the author" do
    2.times do |i|
      post "/api/v1/recipes/#{recipe.id}/reviews", headers: headers(viewer), params: { body: "Review #{i}", rating: i + 3 }
      expect(response).to have_http_status(:created)
    end
    expect(recipe.recipe_reviews.count).to eq(1)
    get "/api/v1/recipes/#{recipe.id}", headers: headers(viewer)
    expect(json["average_rating"]).to eq(4.0)
    expect(json["reviews_count"]).to eq(1)
    expect(owner.notifications.last.action).to eq("review")
  end

  it "deletes only the current cook's review and updates the aggregate" do
    review = recipe.recipe_reviews.create!(user: viewer, body: "Great", rating: 5)
    delete "/api/v1/recipes/#{recipe.id}/reviews/#{review.id}", headers: headers(owner)
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/recipes/#{recipe.id}/reviews/#{review.id}", headers: headers(viewer)
    expect(response).to have_http_status(:no_content)
    get "/api/v1/recipes/#{recipe.id}"
    expect(json["reviews_count"]).to eq(0)
    expect(json["average_rating"]).to be_nil
  end

  it "allows clearing a gallery without removing its cover image" do
    recipe.photos.attach(io: File.open(Rails.root.join("spec/fixtures/pixel.png")), filename: "pixel.png", content_type: "image/png")
    patch "/api/v1/recipes/#{recipe.id}", headers: headers(owner), params: { photos: [""] }
    expect(response).to have_http_status(:ok)
    expect(recipe.reload.photos.count).to eq(0)
    expect(json["cover_image_url"]).to eq(recipe.cover_image_url)
  end

  it "updates profiles including avatars and searches for cooks" do
    patch "/api/v1/me/account", headers: headers(owner), params: { name: "Unique Chef", bio: "Cooking", avatar: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/pixel.png"), "image/png") }
    expect(response).to have_http_status(:ok)
    expect(json["user"]["avatar_url"]).to be_present
    get "/api/v1/search", params: { q: "Unique Chef" }
    expect(json["users"].first["id"]).to eq(owner.id)
    get "/api/v1/users/#{owner.handle}"
    expect(json["avatar_url"]).to be_present
  end

  it "restores follow state, lists followers and sends only one notification for repeated follows" do
    2.times { post "/api/v1/users/#{owner.handle}/follow", headers: headers(viewer) }
    expect(owner.notifications.where(action: "follow").count).to eq(1)
    get "/api/v1/users/#{owner.handle}", headers: headers(viewer)
    expect(json["following"]).to be(true)
    expect(json["followers_count"]).to eq(1)
    get "/api/v1/users/#{owner.handle}/followers"
    expect(json.first["id"]).to eq(viewer.id)
    delete "/api/v1/users/#{owner.handle}/follow", headers: headers(viewer)
    get "/api/v1/users/#{owner.handle}", headers: headers(viewer)
    expect(json["following"]).to be(false)
  end

  it "creates text-only posts, likes, comments, notifications and supports owner deletion" do
    post "/api/v1/posts", headers: headers(owner), params: { caption: "Dinner tonight" }
    expect(response).to have_http_status(:created)
    id = json["id"]
    2.times { post "/api/v1/posts/#{id}/like", headers: headers(viewer) }
    expect(json["likes_count"]).to eq(1)
    expect(owner.notifications.where(action: "like").count).to eq(1)
    post "/api/v1/posts/#{id}/comments", headers: headers(viewer), params: { body: "Looks good!" }
    expect(response).to have_http_status(:created)
    get "/api/v1/posts/#{id}", headers: headers(viewer)
    expect(json["liked"]).to be(true)
    expect(json["comments_count"]).to eq(1)
    get "/api/v1/notifications", headers: headers(owner)
    expect(json["unread_count"]).to eq(2)
    post "/api/v1/notifications/read", headers: headers(owner)
    get "/api/v1/notifications", headers: headers(owner)
    expect(json["unread_count"]).to eq(0)
    delete "/api/v1/posts/#{id}", headers: headers(viewer)
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/posts/#{id}", headers: headers(owner)
    expect(response).to have_http_status(:no_content)
    expect(Comment.where(post_id: id)).to be_empty
  end

  it "rejects linking a post to somebody else's draft" do
    draft = owner.recipes.create!(title: "Secret", status: "draft")
    post "/api/v1/posts", headers: headers(viewer), params: { caption: "Secret", recipe_id: draft.id }
    expect(response).to have_http_status(:not_found)
  end

  it "plans meals, replaces a slot, builds a shopping list and enforces entry ownership" do
    recipe.recipe_ingredients.create!(name: "Salt", quantity: "1", unit: "tsp")
    2.times do
      post "/api/v1/meal-plans/entries", headers: headers(owner), params: { week: "2026-10-05", date: "2026-10-05", meal_type: "dinner", recipe_id: recipe.id }
      expect(response).to have_http_status(:created)
    end
    expect(json["entries"].size).to eq(1)
    id = json["entries"].first["id"]
    get "/api/v1/meal-plans/shopping-list", headers: headers(owner), params: { week: "2026-10-05" }
    expect(json["items"].first).to include("name" => "Salt", "amounts" => ["1 tsp"])
    delete "/api/v1/meal-plans/entries/#{id}", headers: headers(viewer)
    expect(response).to have_http_status(:not_found)
    delete "/api/v1/meal-plans/entries/#{id}", headers: headers(owner)
    expect(json["entries"]).to be_empty
  end

  it "rejects invalid weeks, dates, meal types and recipe references" do
    ["nonsense", "2026-10-06"].each do |week|
      get "/api/v1/meal-plans", headers: headers(owner), params: { week: week }
      expect(response).to have_http_status(:unprocessable_entity)
    end
    [{ date: "2026-10-13", meal_type: "dinner", recipe_id: recipe.id }, { date: "2026-10-05", meal_type: "snack", recipe_id: recipe.id }, { date: "2026-10-05", meal_type: "dinner", recipe_id: -1 }].each do |params|
      post "/api/v1/meal-plans/entries", headers: headers(owner), params: params.merge(week: "2026-10-05")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it "hides recipe details and shopping ingredients when a planned recipe becomes another cook's draft" do
    recipe.recipe_ingredients.create!(name: "Private ingredient")
    plan = viewer.meal_plans.create!(week_start_date: "2026-10-05")
    plan.meal_plan_entries.create!(recipe: recipe, date: "2026-10-05", meal_type: "dinner")
    recipe.update!(status: "draft")
    get "/api/v1/meal-plans", headers: headers(viewer), params: { week: "2026-10-05" }
    expect(json["entries"].first["recipe"]).to eq("id" => nil, "title" => "Recipe unavailable")
    get "/api/v1/meal-plans/shopping-list", headers: headers(viewer), params: { week: "2026-10-05" }
    expect(json["items"]).to be_empty
    expect(plan.meal_plan_entries.count).to eq(1)
  end

  it "defaults missing week to the current Monday" do
    get "/api/v1/meal-plans", headers: headers(owner)
    expect(response).to have_http_status(:ok)
    expect(json["week_start_date"]).to eq(Date.current.beginning_of_week.iso8601)
  end
end
