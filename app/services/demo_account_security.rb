require "bcrypt"
require "securerandom"

# Rotate only the original demo identities; never delete their content.
class DemoAccountSecurity
  EMAILS = %w[
    mara@tastebite.app
    diego@tastebite.app
    priya@tastebite.app
    sam@tastebite.app
    nina@tastebite.app
  ].freeze

  def self.call
    User.transaction do
      users = User.where("LOWER(email) IN (?)", EMAILS).order(:id).lock.to_a
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
end

