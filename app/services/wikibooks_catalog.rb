class WikibooksCatalog
  PROVIDER = "wikibooks"
  LIMIT = 100
  ID_PATTERN = /\Awikibooks-\d{1,12}\z/
  LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/".freeze
  SUMMARY_FIELDS = %i[provider provider_id title cover_image_url category cuisine provider_url].freeze

  def self.install!
    rows = JSON.parse(Rails.root.join("db/data/wikibooks_recipes.json").read, symbolize_names: true)
    Recipe.transaction do
      rows.each do |row|
        provider_id = "wikibooks-#{row.fetch(:page_id)}"
        Recipe.find_or_create_by!(provider: PROVIDER, provider_id: provider_id) do |recipe|
          title, servings, time_minutes, instructions = row.values_at(:title, :servings, :time_minutes, :instructions)
          recipe.assign_attributes(title: title, servings: servings, time_minutes: time_minutes, status: "published")
          recipe.provider_metadata = {
            provider: PROVIDER, provider_id: provider_id, title: title, category: row.fetch(:category),
            cuisine: row[:cuisine], servings: servings, time_minutes: time_minutes, instructions: instructions,
            provider_url: "https://en.wikibooks.org/w/index.php?oldid=#{row.fetch(:revision_id)}",
            license_url: LICENSE_URL
          }
          row.fetch(:ingredients).each_with_index do |(name, amount, calculable), index|
            measurement = if calculable == false
              { original_measurement: amount, quantity_issue: "Amount or unit needs review" }
            else
              parsed = ProviderMeasurement.parse(amount)
              raise ArgumentError, "Invalid catalog measurement: #{title}, #{name}, #{amount}" if parsed[:quantity_issue]
              parsed
            end
            recipe.recipe_ingredients.build(measurement.merge(name: name, position: index + 1))
          end
          recipe.recipe_steps.build(instruction: instructions, position: 1)
        end
      end
    end
  end

  def catalogs
    {
      categories: recipes.filter_map { |recipe| recipe.provider_metadata["category"] }.uniq.sort,
      cuisines: recipes.filter_map { |recipe| recipe.provider_metadata["cuisine"] }.uniq.sort,
      ingredients: recipes.flat_map { |recipe| recipe.recipe_ingredients.map(&:name) }.uniq.sort
    }
  end

  def search(q: nil, category: nil, cuisine: nil, ingredient: nil)
    values = [q, category, cuisine, ingredient].map { |value| value.to_s.strip.downcase }
    if values.any? { |value| value.length > 100 }
      raise TheMealDb::InvalidQuery, "Search and filter values must be at most 100 characters."
    end
    query, category_filter, cuisine_filter, ingredient_filter = values
    raise TheMealDb::InvalidQuery, "Select one ingredient." if ingredient_filter.include?(",")

    recipes.select do |recipe|
      metadata = recipe.provider_metadata
      recipe.title.downcase.include?(query) &&
        (category_filter.empty? || metadata["category"].to_s.downcase == category_filter) &&
        (cuisine_filter.empty? || metadata["cuisine"].to_s.downcase == cuisine_filter) &&
        (ingredient_filter.empty? || recipe.recipe_ingredients.any? { |item| item.name.downcase == ingredient_filter })
    end.first(LIMIT).map { |recipe| recipe.provider_metadata.symbolize_keys.slice(*SUMMARY_FIELDS) }
  end

  def self.find!(id)
    Recipe.published.find_by(provider: PROVIDER, provider_id: id) ||
      raise(TheMealDb::NotFound, "Wikibooks recipe is unavailable.")
  end

  private

  def recipes
    @recipes ||= Recipe.published.where(provider: PROVIDER).includes(:recipe_ingredients).order(:title).to_a
  end
end
