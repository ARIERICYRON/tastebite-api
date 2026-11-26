# A fresh db:prepare can load the schema instead of running the data migration.
Rake::Task["db:prepare"].enhance do
  WikibooksCatalog.install! unless Recipe.exists?(provider: WikibooksCatalog::PROVIDER)
end
