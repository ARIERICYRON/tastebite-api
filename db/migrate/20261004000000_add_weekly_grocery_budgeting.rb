class AddWeeklyGroceryBudgeting < ActiveRecord::Migration[7.1]
  def change
    add_column :meal_plans, :weekly_budget, :decimal, precision: 12, scale: 2
    add_column :meal_plans, :location, :string, default: "Toronto", null: false
    add_column :meal_plan_entries, :servings, :decimal, precision: 10, scale: 2
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE meal_plan_entries SET servings = recipes.servings
          FROM recipes WHERE recipes.id = meal_plan_entries.recipe_id AND recipes.servings > 0
        SQL
      end
    end
    create_table :shopping_items do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.string :ingredient_key, null: false
      t.boolean :checked, default: false, null: false
      t.boolean :pantry, default: false, null: false
      t.decimal :package_price, precision: 12, scale: 2
      t.decimal :package_size, precision: 16, scale: 4
      t.string :package_unit
      t.timestamps
    end
    add_index :shopping_items, [:meal_plan_id, :ingredient_key], unique: true
  end
end
