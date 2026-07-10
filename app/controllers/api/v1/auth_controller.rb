module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate!, only: [:me, :update_account]

      def signup
        user = User.new(user_params)
        if user.save
          render json: { token: encode_token(user.id), user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email].to_s.downcase)
        if user&.authenticate(params[:password])
          render json: { token: encode_token(user.id), user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def me
        render json: { user: user_json(current_user) }
      end

      # PATCH /api/v1/me/account
      def update_account
        if current_user.update(account_params)
          render json: { user: user_json(current_user) }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.permit(:name, :handle, :email, :password)
      end

      def account_params
        params.permit(:name, :handle, :bio)
      end

      def user_json(user)
        { id: user.id, name: user.name, handle: user.handle, email: user.email, bio: user.bio }
      end
    end
  end
end
