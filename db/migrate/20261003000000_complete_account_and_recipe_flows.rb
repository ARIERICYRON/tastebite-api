class CompleteAccountAndRecipeFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :token_version, :integer, default: 0, null: false
    # Keep community posts when their linked recipe is deleted.
    change_column_null :posts, :recipe_id, true
  end
end
