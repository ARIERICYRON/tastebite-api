class AddProfileFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :bio, :text
    add_column :users, :avatar_url, :string
    add_column :users, :location, :string
  end
end
