module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate!, only: [:me]

      # POST /api/v1/auth/signup
      def signup
        user = User.new(user_params)
        if user.save
          render json: { token: encode_token(user.id), user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email].to_s.downcase)
        if user&.authenticate(params[:password])
          render json: { token: encode_token(user.id), user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      # GET /api/v1/me
      def me
        render json: { user: user_json(current_user) }
      end

      private

      def user_params
        params.permit(:name, :handle, :email, :password)
      end

      def user_json(user)
        { id: user.id, name: user.name, handle: user.handle, email: user.email }
      end
    end
  end
end