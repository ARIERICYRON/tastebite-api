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
