class ApplicationController < ActionController::API
  # Create a login token for a user
  def encode_token(user_id)
    JWT.encode({ user_id: user_id, version: User.find(user_id).token_version, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base, "HS256")
  end

  # Figure out who is logged in from their token
  def current_user
    header = request.headers["Authorization"]
    return nil unless header
    token = header.split(" ").last
    decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
    user = User.find_by(id: decoded["user_id"])
    user if user && decoded["version"].to_i == user.token_version
  rescue JWT::DecodeError
    nil
  end

  # Block access if nobody is logged in
  def authenticate!
    render json: { error: "Not logged in" }, status: :unauthorized unless current_user
  end
end