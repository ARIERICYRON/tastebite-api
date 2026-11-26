require "bcrypt"
require "securerandom"

# This data-only migration uses a local model to avoid future application callbacks.
class SecureSeededDemoAccounts < ActiveRecord::Migration[7.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  DEMO_EMAILS = %w[
    mara@tastebite.app diego@tastebite.app priya@tastebite.app
    sam@tastebite.app nina@tastebite.app
  ].freeze

  def up
    unless column_exists?(:users, :token_version)
      raise "Session-version support must be deployed before securing demo accounts."
    end
    MigrationUser.reset_column_information
    operation = lambda do
      MigrationUser.transaction do
        users = MigrationUser.where("LOWER(email) IN (?)", DEMO_EMAILS).order(:id).lock.to_a
        users.each do |user|
          user.update_columns(
            password_digest: BCrypt::Password.create(SecureRandom.hex(32)).to_s,
            token_version: user.token_version.to_i + 1,
            updated_at: Time.current
          )
        end
        users.length
      end
    end
    # Avoid SQL debug logging of password digests; report the affected count only.
    logger = ActiveRecord::Base.logger
    count = logger.respond_to?(:silence) ? logger.silence { operation.call } : operation.call
    say "Secured #{count} demo account(s). Existing users and content were preserved."
    count
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Random credential rotation cannot be reversed."
  end
end

