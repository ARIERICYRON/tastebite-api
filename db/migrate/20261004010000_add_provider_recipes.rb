class AddProviderRecipes < ActiveRecord::Migration[7.1]
  def change
    change_column_null :recipes, :user_id, true
    add_column :recipes, :provider, :string
    add_column :recipes, :provider_id, :string
    add_column :recipes, :provider_metadata, :jsonb, default: {}, null: false
    add_index :recipes, [:provider, :provider_id], unique: true, where: "provider IS NOT NULL"
    add_check_constraint :recipes, "(provider IS NULL AND provider_id IS NULL AND user_id IS NOT NULL) OR (provider = 'themealdb' AND provider_id IS NOT NULL AND user_id IS NULL)", name: "recipes_authorship_or_provider"
    add_column :recipe_ingredients, :original_measurement, :text
    add_column :recipe_ingredients, :quantity_issue, :string
    add_column :meal_plan_entries, :base_servings, :decimal, precision: 10, scale: 2
  end
end
