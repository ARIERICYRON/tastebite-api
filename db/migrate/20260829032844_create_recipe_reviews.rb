class CreateRecipeReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :recipe_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.integer :rating
      t.text :body

      t.timestamps
    end
  end
end
