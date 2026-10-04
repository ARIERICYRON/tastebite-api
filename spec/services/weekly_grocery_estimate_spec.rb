require "rails_helper"

RSpec.describe WeeklyGroceryEstimate do
  let(:user) { create(:user) }
  let(:plan) { user.meal_plans.create!(week_start_date: "2026-10-05") }
  def add(quantity, unit, name: "Flour", servings: 2, planned: nil, date: "2026-10-05", meal: "dinner")
    recipe = user.recipes.create!(title: "Dish", status: "published", servings: servings)
    recipe.recipe_ingredients.create!(name: name, quantity: quantity, unit: unit)
    plan.meal_plan_entries.create!(recipe: recipe, date: date, meal_type: meal, servings: planned)
  end
  def price(key = "flour", amount: 4, size: 500, unit: "g", pantry: false)
    plan.shopping_items.create!(ingredient_key: key, package_price: amount, package_size: size, package_unit: unit, pantry: pantry)
  end
  def estimate
    described_class.new(plan).call
  end

  it "defaults to Toronto and CAD, with no assumed budget or price" do
    add("100", "g")
    result = estimate
    expect(result).to include(location: "Toronto", currency: "CAD", price_source: "manual", weekly_budget: nil, complete: false, estimated_total: nil, budget_remaining: nil, missing_prices: ["Flour"])
    expect(result[:items].first[:purchase_cost]).to be_nil
    expect(result[:items].first[:ingredient_use_cost]).to be_nil
  end

  it "scales servings, combines names and compatible units, and rounds packages after weekly reuse" do
    add("100", "g", planned: 4)
    add("0.1", "kg", name: " flour ", date: "2026-10-06")
    price
    result = estimate
    item = result[:items].first
    expect(result[:items].size).to eq(1)
    expect(item[:quantities]).to eq([{ quantity: "300", unit: "g" }])
    expect(item).to include(packages_to_buy: 1, ingredient_use_cost: 2.4, purchase_cost: 4.0)
    expect(result).to include(estimated_total: 4.0, ingredient_use_total: 2.4, complete: true)
  end

  it "calculates the 600 g example using two 500 g packages at four CAD each" do
    add("100", "g", planned: 10)
    add("100", "g", date: "2026-10-06")
    price
    expect(estimate[:items].first).to include(quantities: [{ quantity: "600", unit: "g" }], packages_to_buy: 2, ingredient_use_cost: 4.8, purchase_cost: 8.0)
    expect(estimate).to include(ingredient_use_total: 4.8, estimated_total: 8.0, complete: true)
  end

  it "keeps tiny positive demands visible when one package must still be bought" do
    add("0.00001", "g")
    price
    expect(estimate[:items].first).to include(quantities: [{ quantity: "<0.0001", unit: "g" }], packages_to_buy: 1, purchase_cost: 4.0)
    expect(GroceryQuantity.display(0.to_r)).to eq("0")
  end

  it "calculates packages from quantity and size even when the manual price is missing" do
    add("600", "g")
    price(amount: nil)
    expect(estimate[:items].first).to include(packages_to_buy: 2, purchase_cost: nil, ingredient_use_cost: nil, missing_price: true)
    expect(estimate).to include(complete: false, estimated_total: nil, missing_prices: ["Flour"])
  end

  it "merges Canadian cups and spoons with litres" do
    add("1/2", "cup", name: "Milk")
    add("1", "tbsp", name: "milk", date: "2026-10-06")
    add("2", "tsp", name: "milk", date: "2026-10-07")
    price("milk", amount: 4, size: 1, unit: "l")
    expect(estimate[:items].first).to include(quantities: [{ quantity: "150", unit: "ml" }], ingredient_use_cost: 0.6, purchase_cost: 4.0)
  end

  it "parses mixed and unicode fractions and preserves count units" do
    add("1 1/2", "each", name: "Eggs")
    add("½", "pieces", name: "eggs", date: "2026-10-06")
    price("eggs", amount: 6, size: 12, unit: "each")
    expect(estimate[:items].first).to include(quantities: [{ quantity: "2", unit: "each" }], ingredient_use_cost: 1.0, packages_to_buy: 1)
  end

  it "does not round fractional quantities before calculating packages" do
    add("0.1", "kg")
    add("0.2", "kg", date: "2026-10-06")
    price(size: 300)
    expect(estimate[:items].first[:packages_to_buy]).to eq(1)
    add("0.0001", "g", date: "2026-10-07")
    expect(estimate[:items].first[:packages_to_buy]).to eq(2)
  end

  it "does not convert weight to volume and excludes incomplete items from full totals" do
    add("100", "g")
    add("1", "cup", date: "2026-10-06")
    price
    result = estimate
    expect(result[:items].first[:issues]).to include("Incompatible ingredient and package units")
    expect(result[:items].first[:purchase_cost]).to be_nil
    expect(result[:estimated_total]).to be_nil
    expect(result[:uncalculated_items]).to eq(["Flour"])
  end

  it "preserves unknown quantities and units, with explanations and no false zero cost" do
    add("to taste", "pinch")
    add("1/0", "g", date: "2026-10-06")
    add("2", "bunches", date: "2026-10-07")
    price
    item = estimate[:items].first
    expect(item[:amounts]).to eq(["to taste pinch", "1/0 g", "2 bunches"])
    expect(item[:uncalculated].map { |row| row[:reason] }).to include("Unrecognized quantity", "Unrecognized unit")
    expect(item[:purchase_cost]).to be_nil
    expect(estimate[:estimated_total]).to be_nil
  end

  it "excludes pantry purchases while retaining priced ingredient-use cost" do
    add("100", "g")
    price(pantry: true)
    result = estimate
    expect(result[:items].first).to include(packages_to_buy: 0, purchase_cost: 0.0, ingredient_use_cost: 0.8)
    expect(result).to include(estimated_total: 0.0, ingredient_use_total: 0.8, missing_prices: [])
  end

  it "does not require pantry prices for shopping totals but marks ingredient-use totals incomplete" do
    add("to taste", "", name: "Salt")
    plan.shopping_items.create!(ingredient_key: "salt", pantry: true)
    expect(estimate).to include(complete: true, estimated_total: 0.0, ingredient_use_total: nil, missing_prices: [])
  end

  it "distinguishes an explicitly entered zero price from a missing price" do
    add("100", "g")
    price(amount: 0)
    expect(estimate).to include(complete: true, estimated_total: 0.0, missing_prices: [])
  end

  it "shows complete remaining/exceeded budgets and only a lower bound for incomplete estimates" do
    add("100", "g")
    price
    plan.update!(weekly_budget: 6)
    expect(estimate).to include(budget_remaining: 2.0, budget_status: "within")
    plan.update!(weekly_budget: 3)
    expect(estimate).to include(budget_remaining: -1.0, budget_status: "over")
    add("1", "each", name: "Eggs", date: "2026-10-06")
    expect(estimate).to include(estimated_total: nil, priced_subtotal: 4.0, budget_remaining: nil, minimum_budget_exceeded: 1.0, budget_status: "over_at_least", missing_prices: ["Eggs"])
  end

  it "flags custom servings if the recipe baseline is missing" do
    add("100", "g", servings: nil, planned: 3)
    price
    expect(estimate[:warnings]).not_to be_empty
    expect(estimate[:items].first[:uncalculated].first[:reason]).to eq("Missing recipe servings")
    expect(estimate[:estimated_total]).to be_nil
  end

  it "keeps legacy amounts calculable when no serving override is possible" do
    add("100", "g", servings: nil)
    price
    expect(estimate[:items].first[:quantities]).to eq([{ quantity: "100", unit: "g" }])
    expect(estimate[:estimated_total]).to eq(4.0)
  end

  it "never merges garlic cloves into generic pieces or grams" do
    add("2", "cloves", name: "Garlic")
    price("garlic", unit: "g")
    expect(estimate[:items].first[:purchase_cost]).to be_nil
  end
end
