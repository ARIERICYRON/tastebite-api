require "rails_helper"
RSpec.describe "TheMealDB discovery and import", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }
  let(:detail) do
    client = TheMealDb.new
    allow(client).to receive(:request).and_return(JSON.parse(File.read(Rails.root.join("spec/fixtures/meal_db/meal.json"))))
    client.detail("52771")
  end
  def auth(viewer = user)
    { "Authorization" => "Bearer #{JWT.encode({ user_id: viewer.id, version: viewer.token_version, exp: 1.hour.from_now.to_i }, Rails.application.secret_key_base, 'HS256')}" }
  end
  def json; JSON.parse(response.body); end
  def import(viewer = user)
    post "/api/v1/discover/recipes/52771/import", headers: auth(viewer), params: { save: true }, as: :json
    expect(response).to have_http_status(:created)
    Recipe.find(json["id"])
  end
  before do
    captured = detail
    allow_any_instance_of(TheMealDb).to receive(:detail).with("52771").and_return(captured)
  end
  it "shares one immutable provider recipe and deduplicates each user's saves" do
    recipe = import
    import
    import(other)
    expect(Recipe.where(provider: "themealdb").count).to eq(1)
    expect(Bookmark.where(recipe: recipe).count).to eq(2)
    expect(recipe.user_id).to be_nil
    expect(recipe).to have_attributes(servings: nil, time_minutes: nil, calories: nil)
    patch "/api/v1/recipes/#{recipe.id}", headers: auth, params: { title: "Mine" }
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/recipes/#{recipe.id}", headers: auth(other)
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/recipes/#{recipe.id}/save", headers: auth
    expect(user.bookmarks.where(recipe: recipe)).to be_empty
    expect(other.bookmarks.where(recipe: recipe)).to exist
    post "/api/v1/recipes/#{recipe.id}/reviews", headers: auth, params: { body: "Great", rating: 4 }
    expect(response).to have_http_status(:created)
    expect(Notification.count).to eq(0)
    expect(recipe.reload.title).to eq("Spicy Arrabiata Penne")
  end
  it "keeps provider content out of community discovery and exposes safe attributed saved details" do
    recipe = import
    get "/api/v1/explore/trending", headers: auth
    expect(json).to eq([])
    get "/api/v1/recipes", headers: auth
    expect(json).to eq([])
    get "/api/v1/me/saved", headers: auth
    expect(json.first).to include("provider" => "themealdb", "author" => nil)
    get "/api/v1/recipes/#{recipe.id}", headers: auth
    expect(json["ingredients"].map { |row| row["original_measurement"] }).to include("1 tin ")
  end
  it "requires confirmed base servings and scales only calculable amounts per user's meal" do
    recipe = import
    params = { week: "2026-10-05", date: "2026-10-05", meal_type: "dinner", recipe_id: recipe.id, servings: 4 }
    post "/api/v1/meal-plans/entries", headers: auth, params: params
    expect(response).to have_http_status(:unprocessable_entity)
    post "/api/v1/meal-plans/entries", headers: auth, params: params.merge(base_servings: 2)
    expect(response).to have_http_status(:created)
    entry = json["entries"].first
    post "/api/v1/meal-plans/entries", headers: auth, params: params.merge(base_servings: 2)
    expect(user.meal_plans.first.meal_plan_entries.count).to eq(1)
    post "/api/v1/meal-plans/entries", headers: auth, params: params.merge(base_servings: 2, replace: false), as: :json
    expect(response).to have_http_status(:conflict)
    post "/api/v1/meal-plans/entries", headers: auth(other), params: params.merge(base_servings: 4)
    expect(response).to have_http_status(:created)
    get "/api/v1/meal-plans/shopping-list", headers: auth, params: { week: "2026-10-05" }
    expect(json["items"].find { |row| row["key"] == "penne rigate" }["quantities"]).to eq([{ "quantity" => "907.1847", "unit" => "g" }])
    expect(json["items"].find { |row| row["key"] == "chopped tomatoes" }["uncalculated"].first["amount"]).to eq("1 tin ")
    expect(json["estimated_total"]).to be_nil
    get "/api/v1/meal-plans/shopping-list", headers: auth(other), params: { week: "2026-10-05" }
    expect(json["items"].find { |row| row["key"] == "penne rigate" }["quantities"]).to eq([{ "quantity" => "453.5924", "unit" => "g" }])
    patch "/api/v1/meal-plans/entries/#{entry['id']}", headers: auth(other), params: { base_servings: 1 }
    expect(response).to have_http_status(:not_found)
    patch "/api/v1/meal-plans/entries/#{entry['id']}", headers: auth, params: { base_servings: nil }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
  it "defaults planned servings to the user's confirmed base" do
    recipe = import
    post "/api/v1/meal-plans/entries", headers: auth, params: { week: "2026-10-05", date: "2026-10-05", meal_type: "breakfast", recipe_id: recipe.id, base_servings: 3 }
    expect(response).to have_http_status(:created)
    expect(json["entries"].first).to include("servings" => 3.0, "base_servings" => 3.0)
  end
  it "uses saved snapshots during provider failure and returns clear errors for uncached recipes" do
    recipe = import
    allow_any_instance_of(TheMealDb).to receive(:detail).and_raise(TheMealDb::Unavailable, "Provider unavailable")
    get "/api/v1/discover/recipes/52771", headers: auth
    expect(response).to have_http_status(:ok)
    expect(json).to include("imported_recipe_id" => recipe.id, "snapshot_warning" => "The provider is unavailable. Showing the saved recipe snapshot.")
    get "/api/v1/discover/recipes/999", headers: auth
    expect(response).to have_http_status(:service_unavailable)
  end
  it "returns catalogs/search and rejects unauthenticated imports" do
    allow_any_instance_of(TheMealDb).to receive(:catalogs).and_return(categories: ["Vegetarian"], cuisines: ["Italian"], ingredients: ["Garlic"])
    allow_any_instance_of(TheMealDb).to receive(:search).and_return([detail.slice(:provider_id, :title)])
    get "/api/v1/discover/catalogs", headers: auth, params: { provider: "themealdb" }
    expect(json["cuisines"]).to eq(["Italian"])
    get "/api/v1/discover/recipes", headers: auth, params: { q: "Arrabiata", provider: "themealdb" }
    expect(response).to have_http_status(:ok)
    expect(json["results"].first["provider_id"]).to eq("52771")
    post "/api/v1/discover/recipes/52771/import", params: { save: true }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
