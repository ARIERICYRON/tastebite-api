class CreateRecipes < ActiveRecord::Migration[7.1]
  def change
    create_table :recipes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :difficulty
      t.integer :time_minutes
      t.integer :servings
      t.string :cover_image_url
      t.string :status

      t.timestamps
    end
  end
end
