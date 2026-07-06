require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/signup" do
    it "creates a user and returns a token" do
      post "/api/v1/auth/signup", params: {
        name: "Test Cook", handle: "testcook",
        email: "test@example.com", password: "password123"
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["handle"]).to eq("testcook")
      expect(User.count).to eq(1)
    end

    it "rejects a duplicate email" do
      create(:user, email: "taken@example.com")

      post "/api/v1/auth/signup", params: {
        name: "Another", handle: "another",
        email: "taken@example.com", password: "password123"
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/auth/login" do
    it "logs in with correct credentials" do
      create(:user, email: "me@example.com", password: "password123")

      post "/api/v1/auth/login", params: {
        email: "me@example.com", password: "password123"
      }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token"]).to be_present
    end

    it "rejects wrong password" do
      create(:user, email: "me@example.com", password: "password123")

      post "/api/v1/auth/login", params: {
        email: "me@example.com", password: "wrong"
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
