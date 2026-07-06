module Api
  module V1
    class FollowsController < ApplicationController
      before_action :authenticate!, only: [:create, :destroy]
      before_action :set_target, only: [:create, :destroy, :followers, :following]

      # POST /api/v1/users/:handle/follow
      def create
        if @target.id == current_user.id
          return render json: { error: "You can't follow yourself" }, status: :unprocessable_entity
        end
        current_user.active_follows.find_or_create_by(followed: @target)
        render json: { following: true, handle: @target.handle }, status: :created
      end

      # DELETE /api/v1/users/:handle/follow
      def destroy
        current_user.active_follows.find_by(followed: @target)&.destroy
        render json: { following: false, handle: @target.handle }
      end

      # GET /api/v1/users/:handle/followers
      def followers
        render json: @target.followers.map { |u| user_stub(u) }
      end

      # GET /api/v1/users/:handle/following
      def following
        render json: @target.following.map { |u| user_stub(u) }
      end

      private

      def set_target
        @target = User.find_by(handle: params[:handle])
        render json: { error: "User not found" }, status: :not_found unless @target
      end

      def user_stub(u)
        { id: u.id, name: u.name, handle: u.handle }
      end
    end
  end
end
