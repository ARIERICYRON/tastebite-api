require "rails_helper"

RSpec.describe "Demo seed safety" do
  let(:seed_file) { Rails.root.join("db/seeds.rb") }

  it "does nothing in production even when the database contains users and recipes" do
    owner = create(:user)
    recipe = owner.recipes.create!(title: "Keep this recipe", status: "published")
    original_user = owner.attributes
    original_recipe = recipe.attributes
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

    expect { load seed_file }.to output(/Demo seeds skipped/).to_stdout

    expect(User.count).to eq(1)
    expect(Recipe.count).to eq(1)
    expect(owner.reload.attributes == original_user).to be(true)
    expect(recipe.reload.attributes == original_recipe).to be(true)
  end

  it "refuses a populated local database without changing existing data" do
    owner = create(:user)
    original_user = owner.attributes

    expect { load seed_file }.to raise_error(/Refusing to seed a populated database/)

    expect(User.count).to eq(1)
    expect(owner.reload.attributes == original_user).to be(true)
    expect(Recipe.count).to eq(0)
  end

  it "also refuses existing data that has no local user owner" do
    recipe = Recipe.create!(title: "Existing provider snapshot", status: "published", provider: "themealdb", provider_id: "test-snapshot")
    original_recipe = recipe.attributes

    expect { load seed_file }.to raise_error(/Refusing to seed a populated database/)

    expect(User.count).to eq(0)
    expect(recipe.reload.attributes == original_recipe).to be(true)
  end

  it "creates fresh demo data with independent passwords and emits no credentials" do
    generated = []
    allow(SecureRandom).to receive(:hex).with(32).and_wrap_original do |method, count|
      method.call(count).tap { |value| generated << value }
    end
    output = StringIO.new
    previous_stdout = $stdout
    begin
      $stdout = output
      load seed_file
    ensure
      $stdout = previous_stdout
    end

    users = User.order(:id).to_a
    expect(users.length).to eq(5)
    expect(Recipe.count).to eq(5)
    expect(generated.length).to eq(5)
    expect(generated.uniq.length).to eq(5)
    users.each_with_index do |user, index|
      expect(!!user.authenticate(generated.fetch(index))).to be(true)
      generated.each_with_index do |password, other_index|
        next if index == other_index
        expect(!!user.authenticate(password)).to be(false)
      end
      expect(output.string.include?(user.password_digest)).to be(false)
    end
    expect(generated.any? { |password| output.string.include?(password) }).to be(false)
  end
end

