class ProviderRecipeImport
  def self.call(id)
    existing = Recipe.find_by(provider: "themealdb", provider_id: id)
    return existing if existing
    detail = TheMealDb.new.detail(id)
    Recipe.transaction do
      recipe = Recipe.create!(provider: "themealdb", provider_id: id, title: detail[:title], status: "published", cover_image_url: detail[:cover_image_url], provider_metadata: detail.except(:ingredients))
      detail[:ingredients].each { |ingredient| recipe.recipe_ingredients.create!(ingredient) }
      recipe.recipe_steps.create!(instruction: detail[:instructions], position: 1) if detail[:instructions].present?
      recipe
    end
  rescue ActiveRecord::RecordNotUnique
    Recipe.find_by!(provider: "themealdb", provider_id: id)
  end
end
