class InstallWikibooksCatalog < ActiveRecord::Migration[7.1]
  def up
    remove_check_constraint :recipes, name: "recipes_authorship_or_provider"
    add_check_constraint :recipes, <<~SQL.squish, name: "recipes_authorship_or_provider"
      (provider IS NULL AND provider_id IS NULL AND user_id IS NOT NULL)
      OR (provider IS NOT NULL AND provider IN ('themealdb', 'wikibooks') AND provider_id IS NOT NULL AND user_id IS NULL)
    SQL
    WikibooksCatalog.install!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Catalog recipes can be referenced by bookmarks and meal plans"
  end
end
