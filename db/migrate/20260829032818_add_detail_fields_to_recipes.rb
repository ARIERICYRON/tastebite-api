class AddDetailFieldsToRecipes < ActiveRecord::Migration[7.1]
  def change
    add_column :recipes, :prep_minutes, :integer
    add_column :recipes, :cook_minutes, :integer
    add_column :recipes, :protein_g, :integer
    add_column :recipes, :carbs_g, :integer
    add_column :recipes, :fat_g, :integer
    add_column :recipes, :fiber_g, :integer
    add_column :recipes, :notes, :text
  end
end
