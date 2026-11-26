require "rails_helper"

RSpec.describe "Login during credential rotation", type: :request do
  it "rejects a token issued after a concurrent rotation of the authenticated password" do
    previous_password = "before-rotation-" + SecureRandom.hex(8)
    demo = create(:user, email: DemoAccountSecurity::EMAILS.first, password: previous_password)
    previous_version = demo.token_version

    # Interleave rotation after password verification but before JWT creation.
    allow_any_instance_of(User).to receive(:authenticate).and_wrap_original do |method, *arguments|
      authenticated = method.call(*arguments)
      DemoAccountSecurity.call if authenticated && method.receiver.id == demo.id
      authenticated
    end

    post "/api/v1/auth/login", params: { email: demo.email, password: previous_password }

    expect(response).to have_http_status(:ok)
    token = JSON.parse(response.body).fetch("token")
    expect(demo.reload.token_version).to eq(previous_version + 1)

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:unauthorized)
  end
end
