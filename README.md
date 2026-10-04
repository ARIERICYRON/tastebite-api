# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Completed flow verification and release prerequisites

Run `RAILS_ENV=test bundle exec rails db:migrate`, `bundle exec rspec`, and `RAILS_ENV=test bundle exec rails zeitwerk:check`. These use the local test database and local test image storage. The frontend includes browser regression tests against a separate local database; see its README for setup.

The additive `20261003000000_complete_account_and_recipe_flows` migration adds `users.token_version` (existing JWTs retain version zero) and allows posts to keep their captions when a linked recipe is deleted. It does not delete or rewrite existing records. Do not deploy the new API before applying the migration through the established release process.

Password recovery is implemented with Rails signed, single-use tokens expiring after 30 minutes. A successful reset invalidates older login tokens. Production email delivery requires `SMTP_ADDRESS`, `SMTP_PORT` (default 587), `SMTP_USERNAME`, `SMTP_PASSWORD`, and `MAIL_FROM`. `FRONTEND_URL` defaults to the existing Vercel URL and can be overridden for another environment. In production, recovery returns a clear unavailable response until SMTP is configured. No email credentials have been created or installed by this change.

Google and Apple authentication remain unconfigured: the frontend explicitly disables those buttons. Enabling them requires provider applications, authorized redirect domains, client identifiers/keys, and an OAuth implementation; password-based authentication remains available.

Production uses the existing Cloudflare Active Storage service unchanged. Local tests use disk storage and never upload to or delete Cloudflare objects. Recipe deletion preserves linked community posts, removes that recipe's planner entries, and removes its recipe-owned reviews/bookmarks/ingredients/steps. All deletion actions are initiated by the owner.

## Weekly grocery budgeting

`20261004000000_add_weekly_grocery_budgeting` adds nullable planned servings, weekly budget/location and a `shopping_items` table. Existing meals are backfilled from positive recipe servings; existing users, recipes and storage remain intact. Apply using the normal `bundle exec rails db:migrate` process; do not reset or reload populated databases.

Authenticated endpoints, all scoped to the current user:

- `GET /api/v1/meal-plans/shopping-list?week=YYYY-MM-DD`: aggregated quantities and manual CAD estimates.
- `PATCH /api/v1/meal-plans`: `week`, nullable `weekly_budget`, `location` (Toronto default).
- `POST /api/v1/meal-plans/entries`: existing slot fields plus optional `servings` (recipe default).
- `PATCH /api/v1/meal-plans/entries/:id`: planned `servings`.
- `PATCH /api/v1/meal-plans/shopping-list/items`: `week`, normalized ingredient `key`, optional `checked`, `pantry`, nullable `package_price`/`package_size`, `package_unit`. Omitted fields remain unchanged; JSON null clears a price or size. Removed ingredients retain their settings if re-added to the same week.
- `POST /api/v1/meal-plans/shopping-list/import-checks`: `week`, legacy checked ingredient `names`; existing server settings take precedence.

`WeeklyGroceryEstimate` scales quantities by planned/recipe servings, merges compatible units using rational arithmetic and rounds purchases only after weekly aggregation. Ingredient-use cost uses the consumed fraction of packages; package-purchase cost uses whole packages. Pantry flags exclude purchases without inventing an ingredient-use cost. Purchased checks are organizational and do not reduce weekly spending. Missing prices/quantities yield null full totals and explicit partial subtotals, not zero. Partial costs already over budget return `over_at_least`. Prices and budgets belong to one user/week and no market-price API is used.

Ingredient names normalize only case/spacing. No mass-to-volume density conversion, synonym matching, tax/fee estimate, partial pantry quantities or package carry-over between weeks is attempted. Metric measures follow [Health Canada's Canadian nutrient file guide](https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data/canadian-nutrient-file-compilation-canadian-food-composition-data-users-guide.html): cup 250 ml, tablespoon 15 ml, teaspoon 5 ml. Recipe amounts using other measurement standards must be adjusted manually. Unknown raw amounts remain in the response with calculation flags.

Regression coverage in `spec/services/weekly_grocery_estimate_spec.rb` and `spec/requests/api/v1/grocery_budgeting_spec.rb` includes compatible/incompatible units, fractions, missing recipe servings, whole-package boundaries, pantry behavior, explicit zero versus missing prices, validation, independent device updates, legacy checks and user/week isolation. No additional credentials or external services are required.

Verified package example: at a manual price of $4 CAD per 500 g package, 300 g weekly demand has $2.40 ingredient-use cost and $4 purchase cost (one package). Increasing weekly demand to 600 g has $4.80 ingredient-use cost and $8 purchase cost (two packages). Both examples are covered by Rails and browser tests. Positive aggregated quantities below 0.0001 units display as `<0.0001` rather than zero; purchases use the unrounded quantity.
