class CreateMealPlanEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :meal_plan_entries do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.date :date
      t.string :meal_type

      t.timestamps
    end
  end
end
