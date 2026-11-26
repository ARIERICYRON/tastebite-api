require "rails_helper"

require Rails.root.join("db/migrate/20261126000000_secure_seeded_demo_accounts").to_s unless defined?(SecureSeededDemoAccounts)

RSpec.describe "Secured demo authentication", type: :request do
  def bearer_for(user)
    token = JWT.encode(
      { user_id: user.id, version: user.token_version, exp: 1.hour.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
    { "Authorization" => "Bearer #{token}" }
  end

  shared_examples "invalidated demo credentials" do
    it "invalidates old demo sessions and reset links while retaining unrelated sessions" do
      previous_password = "before-rotation-" + SecureRandom.hex(8)
      demo = create(:user, email: DemoAccountSecurity::EMAILS.first, password: previous_password)
      outsider = create(:user)
      demo_headers = bearer_for(demo)
      outsider_headers = bearer_for(outsider)
      previous_reset_token = demo.generate_token_for(:password_reset)
      get "/api/v1/me", headers: demo_headers
      expect(response).to have_http_status(:ok)
      expect(User.find_by_token_for(:password_reset, previous_reset_token).id).to eq(demo.id)

      rotate_accounts.call

      get "/api/v1/me", headers: demo_headers
      expect(response).to have_http_status(:unauthorized)
      expect(User.find_by_token_for(:password_reset, previous_reset_token)).to be_nil
      post "/api/v1/auth/login", params: { email: demo.email, password: previous_password }
      expect(response).to have_http_status(:unauthorized)
      get "/api/v1/me", headers: outsider_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("user").fetch("id")).to eq(outsider.id)
    end
  end

  context "using the maintenance service" do
    let(:rotate_accounts) { -> { DemoAccountSecurity.call } }
    include_examples "invalidated demo credentials"
  end

  context "using the deployment migration" do
    let(:rotate_accounts) { -> { SecureSeededDemoAccounts.new.up } }
    include_examples "invalidated demo credentials"
  end
end

