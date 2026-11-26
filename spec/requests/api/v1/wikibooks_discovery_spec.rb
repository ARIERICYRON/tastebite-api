require "rails_helper"

RSpec.describe "Wikibooks discovery", type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = JWT.encode({ user_id: user.id, version: user.token_version, exp: 1.hour.from_now.to_i },
                       Rails.application.secret_key_base, "HS256")
    { "Authorization" => "Bearer #{token}" }
  end
  let(:path) { "/api/v1/discover/recipes/wikibooks-17844" }

  before do
    WikibooksCatalog.install!
    expect(TheMealDb).not_to receive(:new)
  end

  def json
    response.parsed_body
  end

  it "lists the database catalog by default and intersects all filters" do
    get "/api/v1/discover/catalogs", headers: headers
    expect(json["cuisines"]).to include("Indian")
    expect(json["ingredients"]).to include("All-purpose flour")

    get "/api/v1/discover/recipes", headers: headers
    expect(json["results"].size).to eq(20)
    expect(json["results"].pluck("provider").uniq).to eq(["wikibooks"])

    get "/api/v1/discover/recipes", headers: headers,
        params: { q: "naa", cuisine: "Indian", category: "Bread", ingredient: "All-purpose flour" }
    expect(json["results"].pluck("title")).to eq(["Naan"])

    get "/api/v1/discover/recipes", headers: headers,
        params: { q: "naa", cuisine: "Indian", category: "Soup", ingredient: "All-purpose flour" }
    expect(json["results"]).to be_empty
  end

  it "exposes attribution, reuses the shared recipe, and scales from the source servings" do
    get path, headers: headers
    expect(json).to include("servings" => 1, "saved" => false,
                            "provider_url" => "https://en.wikibooks.org/w/index.php?oldid=4606890",
                            "license_url" => WikibooksCatalog::LICENSE_URL)
    recipe_id = json.fetch("imported_recipe_id")

    post "#{path}/import", headers: headers, params: { save: false }, as: :json
    expect(json["id"]).to eq(recipe_id)
    expect(user.bookmarks).to be_empty

    2.times { post "#{path}/import", headers: headers }
    expect(user.bookmarks.where(recipe_id: recipe_id).count).to eq(1)

    week = "2026-10-05"
    post "/api/v1/meal-plans/entries", headers: headers, as: :json,
         params: { week: week, date: week, meal_type: "breakfast", recipe_id: recipe_id, servings: 2, base_servings: 99 }
    expect(response).to have_http_status(:created)
    expect(json["entries"].first).to include("servings" => 2.0, "base_servings" => 1.0)

    get "/api/v1/meal-plans/shopping-list", headers: headers, params: { week: week }
    expect(json["items"].find { |item| item["key"] == "rolled oats" }["quantities"])
      .to eq([{ "quantity" => "90", "unit" => "g" }])
  end

  it "keeps unverified amounts along with the recipe's scalable quantities" do
    get "/api/v1/discover/recipes/wikibooks-33064", headers: headers
    water = json["ingredients"].find { |ingredient| ingredient["name"] == "Water" }
    expect(water).to include("original_measurement" => "About 180 ml", "quantity" => nil)
    expect(water["quantity_issue"]).to be_present

    get "/api/v1/discover/recipes/wikibooks-999999", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
