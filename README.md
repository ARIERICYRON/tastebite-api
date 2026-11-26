# README

## Demo-account safety

Demo seeds run only in development or test and refuse to modify a populated database. Each seeded account receives an independent random password; no shared demo login is provided. Create your own local account for interactive testing.

The `20261126000000_secure_seeded_demo_accounts` migration rotates credentials for the five original demo email identities and invalidates their existing sessions and password-reset links. It preserves users and their content. Production seeding is skipped. The `demo_accounts:secure` maintenance task can repeat the targeted rotation when explicitly needed; it reports only the number of accounts secured.

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

The three-tab planner displays automatic package counts even before a manual price is entered, provided quantity and package units/sizes are compatible. Missing price still yields null purchase/use costs and an incomplete total. Service regression coverage verifies this independently of cost calculation.

## Legacy TheMealDB provider recipes

The Rails-only client uses `THEMEALDB_API_KEY`, defaulting to public test key `1` outside production. Routes under `/api/v1/discover` require authentication: `GET /catalogs?provider=themealdb`, `GET /recipes?provider=themealdb&q=&category=&cuisine=&ingredient=`, `GET /recipes/:provider_id` and `POST /recipes/:provider_id/import` (`save:false` imports without bookmarking). Search intersects separate V1 single-filter requests, with a 100-row bound per request. No paid V2 features are used. Open/read/write timeouts are 3/5/5 seconds, response bodies are bounded, and provider errors become 404/422/503 responses without exposing keys. Catalogs/search/details have 24-hour/5-minute/1-hour cache lifetimes when a cache store is configured.

Apply `bundle exec rails db:migrate`. The additive migration stores provider identity/metadata, exact original measurements and calculation flags, and per-entry confirmed `base_servings`. A unique provider identity prevents duplicate snapshots. Provider recipes have no local author, are excluded from community discovery and cannot be edited/deleted through recipe endpoints. Bookmarks and meal planning use the existing data model. Imported snapshots stay stable to preserve planned quantities; details use the same snapshot. No remote images are copied to Cloudflare.

Provider planning requires positive confirmed base servings; planned servings default to that confirmation. Scaling uses planned/base servings per meal, keeping confirmations isolated between users. Numeric known-unit measurements are parsed conservatively; ranges, package descriptions, unsupported words and unspecified provider cup volumes remain raw and flagged. No invented nutrition/time/servings or density conversions. Unknown quantities prevent complete cost totals; existing manual CAD prices, package aggregation, pantry flags and user/week isolation apply. `replace:false` on entry creation returns 409 for occupied slots under the plan lock.

**Production release prerequisite:** obtain and record commercial-access confirmation from TheMealDB and configure an appropriate production key before setting `THEMEALDB_COMMERCIAL_ACCESS_CONFIRMED=true`. Production explicitly rejects development key `1`. Review the [official API documentation](https://www.themealdb.com/api.php) and [terms of use](https://www.themealdb.com/terms_of_use.php); no plan has been purchased. Keep keys out of frontend environment variables and Git. Deployment/storage settings remain unchanged.

Run `bundle exec rspec`. Provider service/request specs cover transport timeouts, filters, original quantities, deduplicated immutable imports, confirmed scaling, unknown costs and user isolation. Browser tests may opt into `TASTEBITE_MEALDB_FIXTURE=1` only with `RAILS_ENV=test` and the isolated `tastebite_api_flow_test` database. `spec/browser_support/meal_db_fixture.rb` replaces upstream transport using a captured official recipe and cannot load outside test mode. Production and development still call the real provider.

## Wikibooks starter catalog

Discover reads 20 shared Wikibooks Cookbook recipes from the Rails database. The
catalog was curated from Wikimedia's Action API and ships with the app in
`db/data/wikibooks_recipes.json`. The production search, filter, save and meal
planning flows use the database without any external API credentials or requests.
The existing TheMealDB snapshots keep their original identifiers and links.
The legacy search endpoints accept `provider=themealdb` explicitly.

Apply `bundle exec rails db:migrate` before releasing the accompanying frontend.
The additive migration installs the catalog without altering existing recipes,
users or meals. To populate the catalog after a manual schema load, run
`bundle exec rails runner 'WikibooksCatalog.install!'` against that database.
The installer can be rerun and preserves existing snapshots.

The adapted recipe text in the catalog is credited to Wikibooks Cookbook
contributors and licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Each entry pins the source revision. TasteBite normalizes ingredient names and
measurable amounts, selects a recipe variation where applicable, and adapts
instructions. Unverified measures are shown and flagged in grocery lists.
The catalog contains no imported images.
