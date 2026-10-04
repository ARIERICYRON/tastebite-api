require "rails_helper"

RSpec.describe "Weekly grocery budgeting", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }
  let(:recipe) do
    user.recipes.create!(title: "Flour dish", status: "published", servings: 2,
      recipe_ingredients_attributes: [{ name: "Flour", quantity: "100", unit: "g" }])
  end
  def headers(viewer = user)
    token = JWT.encode({ user_id: viewer.id, version: viewer.token_version, exp: 1.hour.from_now.to_i }, Rails.application.secret_key_base, "HS256")
    { "Authorization" => "Bearer #{token}" }
  end
  def json
    JSON.parse(response.body)
  end
  def add(viewer = user, week = "2026-10-05", **attrs)
    post "/api/v1/meal-plans/entries", headers: headers(viewer), params: { week: week, date: week, meal_type: "dinner", recipe_id: recipe.id }.merge(attrs)
    expect(response).to have_http_status(:created)
    json["entries"].first["id"]
  end
  def item(viewer = user, week = "2026-10-05", **fields)
    patch "/api/v1/meal-plans/shopping-list/items", headers: headers(viewer), params: { week: week, key: "flour" }.merge(fields), as: :json
  end
  def list(viewer = user, week = "2026-10-05")
    get "/api/v1/meal-plans/shopping-list", headers: headers(viewer), params: { week: week }
    json
  end

  it "persists checks, pantry, manual prices, budget and Toronto/CAD settings per user and week" do
    add
    add(other)
    add(user, "2026-10-12")
    item(user, checked: true, pantry: true, package_price: "4.50", package_size: 500, package_unit: "g")
    expect(response).to have_http_status(:ok)
    patch "/api/v1/meal-plans", headers: headers, params: { week: "2026-10-05", weekly_budget: 30, location: "Toronto" }
    expect(response).to have_http_status(:ok)
    expect(list["items"].first).to include("checked" => true, "pantry" => true, "package_price" => 4.5)
    expect(list["weekly_budget"]).to eq(30.0)
    expect(list(other)["items"].first).to include("checked" => false, "pantry" => false, "package_price" => nil)
    expect(list(other)["weekly_budget"]).to be_nil
    expect(list(user, "2026-10-12")["items"].first["checked"]).to be(false)
    expect(ShoppingItem.count).to eq(1)
  end

  it "defaults servings, updates them and protects entries from another user" do
    id = add
    expect(json["entries"].first["servings"]).to eq(2.0)
    patch "/api/v1/meal-plans/entries/#{id}", headers: headers(other), params: { servings: 10 }
    expect(response).to have_http_status(:not_found)
    patch "/api/v1/meal-plans/entries/#{id}", headers: headers, params: { servings: 4 }
    expect(response).to have_http_status(:ok)
    expect(list["items"].first["quantities"]).to eq([{ "quantity" => "200", "unit" => "g" }])
    patch "/api/v1/meal-plans/entries/#{id}", headers: headers, params: { servings: 0 }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "preserves existing item fields during independent device updates" do
    add
    item(user, checked: true)
    item(user, pantry: true)
    item(user, package_price: 4, package_size: 500, package_unit: "g")
    expect(list["items"].first).to include("checked" => true, "pantry" => true, "package_price" => 4.0)
  end

  it "can clear prices and budget and never reports a full total for missing prices" do
    add
    item(user, package_price: 4, package_size: 500, package_unit: "g")
    expect(json["estimated_total"]).to eq(4.0)
    item(user, package_price: nil)
    expect(response).to have_http_status(:ok)
    expect(json).to include("estimated_total" => nil, "missing_prices" => ["Flour"])
    patch "/api/v1/meal-plans", headers: headers, params: { week: "2026-10-05", weekly_budget: 5 }
    patch "/api/v1/meal-plans", headers: headers, params: { week: "2026-10-05", weekly_budget: nil }, as: :json
    expect(json["weekly_budget"]).to be_nil
  end

  it "rejects invalid prices, packages, budgets, locations, unknown items and unauthenticated writes" do
    add
    [{ package_price: -1 }, { package_price: "oops" }, { package_size: 0 }, { package_size: -2 }].each do |fields|
      item(user, **fields)
      expect(response).to have_http_status(:unprocessable_entity)
    end
    item(other, checked: true)
    expect(response).to have_http_status(:not_found)
    [{ weekly_budget: -1 }, { weekly_budget: "oops" }, { location: "" }].each do |fields|
      patch "/api/v1/meal-plans", headers: headers, params: { week: "2026-10-05" }.merge(fields)
      expect(response).to have_http_status(:unprocessable_entity)
    end
    patch "/api/v1/meal-plans/shopping-list/items", params: { week: "2026-10-05", key: "flour", checked: true }
    expect(response).to have_http_status(:unauthorized)
  end

  it "keeps checks and prices when a meal is removed and later added again" do
    id = add
    item(user, checked: true, package_price: 4, package_size: 500, package_unit: "g")
    delete "/api/v1/meal-plans/entries/#{id}", headers: headers
    expect(list["items"]).to be_empty
    add
    expect(list["items"].first).to include("checked" => true, "package_price" => 4.0)
  end

  it "imports legacy browser checks once without overriding newer server choices" do
    add
    item(user, checked: false)
    post "/api/v1/meal-plans/shopping-list/import-checks", headers: headers, params: { week: "2026-10-05", names: ["Flour", " Salt "] }
    expect(response).to have_http_status(:ok)
    expect(list["items"].first["checked"]).to be(false)
    expect(user.meal_plans.first.shopping_items.find_by(ingredient_key: "salt").checked).to be(true)
    expect(other.meal_plans).to be_empty
  end
end
