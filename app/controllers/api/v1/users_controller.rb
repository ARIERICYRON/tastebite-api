module Api
  module V1
    class UsersController < ApplicationController
      # GET /api/v1/users/:handle
      def show
        user = User.find_by(handle: params[:handle])
        return render json: { error: "User not found" }, status: :not_found unless user

        render json: {
          id: user.id, name: user.name, handle: user.handle, bio: user.bio,
          followers_count: user.followers.count,
          following_count: user.following.count,
          recipes_count: user.recipes.count,
          recipes: user.recipes.order(created_at: :desc).map { |r|
            { id: r.id, title: r.title, difficulty: r.difficulty, time_minutes: r.time_minutes }
          }
        }
      end
    end
  end
end
