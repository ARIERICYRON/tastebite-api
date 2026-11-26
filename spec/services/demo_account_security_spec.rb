require "rails_helper"

RSpec.describe DemoAccountSecurity do
  it "secures the exact demo emails case-insensitively and preserves all other data" do
    previous_password = "before-rotation-" + SecureRandom.hex(8)
    demos = described_class::EMAILS.each_with_index.map do |email, index|
      create(:user, email: email, handle: "renamed_demo_#{index}", password: previous_password)
    end
    demos.first.update_column(:email, demos.first.email.upcase)
    outsider = create(:user, name: demos.first.name, handle: "mara", email: "owner@example.org")
    recipe = demos.first.recipes.create!(title: "Retain this recipe", status: "published")
    post = demos.first.posts.create!(recipe: recipe, caption: "Retain this post")
    immutable_users = demos.map { |user| user.reload.attributes.except("password_digest", "token_version", "updated_at") }
    versions = demos.map(&:token_version)
    outsider_attributes = outsider.attributes
    recipe_attributes = recipe.attributes
    post_attributes = post.attributes
    generated = []
    allow(SecureRandom).to receive(:hex).with(32).and_wrap_original do |method, count|
      method.call(count).tap { |value| generated << value }
    end

    expect(described_class.call).to eq(5)

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
    end
    expect(outsider.reload.attributes == outsider_attributes).to be(true)
    expect(recipe.reload.attributes == recipe_attributes).to be(true)
    expect(post.reload.attributes == post_attributes).to be(true)
  end

  it "rolls back every account if one rotation fails" do
    demos = described_class::EMAILS.first(2).each_with_index.map do |email, index|
      create(:user, email: email, handle: "rollback_demo_#{index}")
    end
    original_attributes = demos.map(&:attributes)
    allow_any_instance_of(User).to receive(:update_columns).and_wrap_original do |method, *args|
      raise ActiveRecord::RecordInvalid.new(method.receiver) if method.receiver.id == demos.last.id
      method.call(*args)
    end

    expect { described_class.call }.to raise_error(ActiveRecord::RecordInvalid)

    demos.each_with_index do |user, index|
      expect(user.reload.attributes == original_attributes[index]).to be(true)
    end
  end

  it "leaves unrelated users unchanged when no original demo accounts exist" do
    outsider = create(:user)
    original_attributes = outsider.attributes

    expect(described_class.call).to eq(0)

    expect(outsider.reload.attributes == original_attributes).to be(true)
  end
end

