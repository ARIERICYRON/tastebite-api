module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate!, only: [:me, :update_account]

      def signup
        user = User.new(user_params)
        if user.save
          render json: { token: encode_token(user), user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.where("LOWER(email) = ?", params[:email].to_s.strip.downcase).first
        if user&.authenticate(params[:password])
          render json: { token: encode_token(user), user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def forgot_password
        if Rails.env.production? && ENV["SMTP_ADDRESS"].blank?
          return render json: { error: "Password recovery email delivery is not configured yet." }, status: :service_unavailable
        end
        # Never disclose whether an email belongs to an account.
        user = User.where("LOWER(email) = ?", params[:email].to_s.strip.downcase).first
        PasswordMailer.reset(user).deliver_now if user
        render json: { message: "If an account exists for that email, a reset link has been sent." }
      end

      def reset_password
        user = User.find_by_token_for(:password_reset, params[:token].to_s)
        return render json: { error: "This reset link is invalid or expired." }, status: :unprocessable_entity unless user
        user.with_lock do
          # Recheck under the lock so concurrent submissions cannot reuse a token.
          unless User.find_by_token_for(:password_reset, params[:token].to_s)
            return render json: { error: "This reset link is invalid or expired." }, status: :unprocessable_entity
          end
          if params[:password].blank?
            return render json: { errors: ["Password can't be blank"] }, status: :unprocessable_entity
          end
          user.password = params[:password]
          user.password_confirmation = params[:password_confirmation]
          user.token_version += 1
          if user.save
            render json: { message: "Password updated. Please log in." }
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
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
        params.permit(:name, :handle, :bio, :avatar)
      end

      def user_json(user)
        { id: user.id, name: user.name, handle: user.handle, email: user.email, bio: user.bio, avatar_url: (user.avatar.attached? ? url_for(user.avatar) : nil) }
      end
    end
  end
end
