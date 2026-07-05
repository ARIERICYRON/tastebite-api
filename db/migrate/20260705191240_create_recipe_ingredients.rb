class CreateRecipeIngredients < ActiveRecord::Migration[7.1]
  def change
    create_table :recipe_ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      t.string :name
      t.string :quantity
      t.string :unit
      t.integer :position

      t.timestamps
    end
  end
end
