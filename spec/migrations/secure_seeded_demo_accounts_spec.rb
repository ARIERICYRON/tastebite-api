require "rails_helper"
require Rails.root.join("db/migrate/20261126000000_secure_seeded_demo_accounts").to_s unless defined?(SecureSeededDemoAccounts)

RSpec.describe SecureSeededDemoAccounts do
  it "rotates all five demo identities, preserves data, and reports only their count" do
    previous_password = "before-migration-" + SecureRandom.hex(8)
    demos = described_class::DEMO_EMAILS.each_with_index.map do |email, index|
      create(:user, email: email, handle: "renamed_migration_#{index}", password: previous_password)
    end
    demos.first.update_column(:email, demos.first.email.upcase)
    outsider = create(:user, handle: "mara", email: "owner@example.org")
    recipe = demos.first.recipes.create!(title: "Preserve migration content", status: "published")
    post = demos.first.posts.create!(recipe: recipe, caption: "Preserve this post")
    immutable_users = demos.map { |user| user.reload.attributes.except("password_digest", "token_version", "updated_at") }
    versions = demos.map(&:token_version)
    outsiders_before = [outsider.attributes, recipe.attributes, post.attributes]
    generated = []
    allow(SecureRandom).to receive(:hex).with(32).and_wrap_original do |method, size|
      method.call(size).tap { |value| generated << value }
    end
    output = StringIO.new
    previous_stdout = $stdout
    begin
      $stdout = output
      result = described_class.new.up
    ensure
      $stdout = previous_stdout
    end

    expect(result).to eq(5)
    expect(output.string).to include("Secured 5 demo account(s)")
    expect(User.count).to eq(6)
    expect(Recipe.count).to eq(1)
    expect(Post.count).to eq(1)
    expect(generated.length).to eq(5)
    expect(generated.uniq.length).to eq(5)
    demos.each_with_index do |user, index|
      user.reload
      expect(user.attributes.except("password_digest", "token_version", "updated_at") == immutable_users[index]).to be(true)
      expect(user.token_version).to eq(versions[index] + 1)
      expect(!!user.authenticate(previous_password)).to be(false)
      expect(!!user.authenticate(generated[index])).to be(true)
      generated.each_with_index do |password, other_index|
        next if index == other_index
        expect(!!user.authenticate(password)).to be(false)
      end
      expect(output.string.include?(user.password_digest)).to be(false)
    end
    expect(generated.any? { |password| output.string.include?(password) }).to be(false)
    expect([outsider.reload.attributes, recipe.reload.attributes, post.reload.attributes] == outsiders_before).to be(true)
  end

  it "rolls back earlier rotations when any account update fails" do
    demos = described_class::DEMO_EMAILS.first(2).each_with_index.map do |email, index|
      create(:user, email: email, handle: "migration_rollback_#{index}")
    end
    original_attributes = demos.map(&:attributes)
    allow_any_instance_of(described_class::MigrationUser).to receive(:update_columns).and_wrap_original do |method, *args|
      raise "Simulated database write failure" if method.receiver.id == demos.last.id
      method.call(*args)
    end

    expect { described_class.new.up }.to raise_error(/Simulated database write failure/)

    demos.each_with_index do |user, index|
      expect(user.reload.attributes == original_attributes[index]).to be(true)
    end
  end

  it "does not rotate unrelated users when no demo identities exist" do
    outsider = create(:user)
    original_attributes = outsider.attributes
    result = nil

    expect { result = described_class.new.up }.to output(/Secured 0 demo account/).to_stdout

    expect(result).to eq(0)
    expect(outsider.reload.attributes == original_attributes).to be(true)
  end
end

