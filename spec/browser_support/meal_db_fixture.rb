# Deterministic provider transport for browser tests only; real Rails imports and budgeting still run.
raise "Browser provider fixture requires test environment" unless Rails.env.test?
module MealDbBrowserFixture
  private
  def request(endpoint, params)
    meal = JSON.parse(File.read(Rails.root.join("spec/fixtures/meal_db/meal.json")))["meals"].first
    values = params.transform_keys(&:to_s)
    if endpoint == "list.php"
      field, value = { "c" => ["strCategory", "Vegetarian"], "a" => ["strArea", "Italian"], "i" => ["strIngredient", "Garlic"] }.fetch(values.keys.first)
      return { "meals" => [{ field => value }] }
    end
    raise TheMealDb::Unavailable, "TheMealDB is temporarily unavailable. Please retry." if values["s"] == "provider failure"
    matched = case endpoint
    when "lookup.php" then values["i"] == meal["idMeal"]
    when "search.php" then !values["s"] || meal["strMeal"].downcase.include?(values["s"].downcase)
    when "filter.php" then values.all? { |key, value| { "c" => "Vegetarian", "a" => "Italian", "i" => "Garlic" }[key]&.casecmp?(value) }
    else false
    end
    { "meals" => matched ? [meal] : nil }
  end
end
TheMealDb.prepend(MealDbBrowserFixture)
