module RecipeSerialization
  def recipe_json(r)
    {
      saved: current_user ? r.bookmarks.exists?(user_id: current_user.id) : false,
      provider: r.provider, provider_id: r.provider_id,
      id: r.id, title: r.title, description: r.description,
      difficulty: r.difficulty, time_minutes: r.time_minutes,
      prep_minutes: r.prep_minutes, cook_minutes: r.cook_minutes,
      servings: r.servings, status: r.status, notes: r.notes,
      cover_image_url: r.cover_image.attached? ? url_for(r.cover_image) : r.cover_image_url,
      photo_signed_ids: current_user&.id == r.user_id ? r.photos.map(&:signed_id) : [],
      photo_urls: r.photos.attached? ? r.photos.map { |p| url_for(p) } : [],
      nutrition: {
        calories: r.calories, protein_g: r.protein_g,
        carbs_g: r.carbs_g, fat_g: r.fat_g, fiber_g: r.fiber_g
      },
      average_rating: r.average_rating,
      reviews_count: r.recipe_reviews.count,
      saves_count: r.bookmarks.count,
      author: r.user && { id: r.user.id, name: r.user.name, handle: r.user.handle,
                avatar_url: (r.user.avatar.attached? ? url_for(r.user.avatar) : nil) },
      ingredients: r.recipe_ingredients.map { |i|
        { id: i.id, name: i.name, quantity: i.quantity, unit: i.unit, position: i.position, original_measurement: i.original_measurement, quantity_issue: i.quantity_issue }
      },
      steps: r.recipe_steps.map { |s|
        { id: s.id, instruction: s.instruction, position: s.position }
      }
    }
  end
end
