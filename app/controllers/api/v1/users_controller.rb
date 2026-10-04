module Api
  module V1
    class UsersController < ApplicationController
      include RecipeSerialization
      # GET /api/v1/users/:handle
      def show
        user = User.find_by(handle: params[:handle])
        return render json: { error: "User not found" }, status: :not_found unless user

        render json: {
          id: user.id, name: user.name, handle: user.handle, bio: user.bio,
          avatar_url: user.avatar.attached? ? url_for(user.avatar) : user.avatar_url,
          following: current_user ? current_user.following.exists?(id: user.id) : false,
          followers_count: user.followers.count,
          following_count: user.following.count,
          recipes_count: user.recipes.published.count,
          recipes: user.recipes.published.order(created_at: :desc).map { |r| recipe_json(r) }
        }
      end
    end
  end
end
