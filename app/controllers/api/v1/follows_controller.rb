module Api
  module V1
    class FollowsController < ApplicationController
      before_action :authenticate!, only: [:create, :destroy]
      before_action :set_target, only: [:create, :destroy, :followers, :following]

      def create
        if @target.id == current_user.id
          return render json: { error: "You can't follow yourself" }, status: :unprocessable_entity
        end
        follow = current_user.active_follows.find_or_create_by!(followed: @target)
        Notification.notify(recipient: @target, actor: current_user, action: "follow") if follow.previously_new_record?
        render json: { following: true, handle: @target.handle }, status: :created
      end

      def destroy
        current_user.active_follows.find_by(followed: @target)&.destroy
        render json: { following: false, handle: @target.handle }
      end

      def followers
        render json: @target.followers.map { |u| user_stub(u) }
      end

      def following
        render json: @target.following.map { |u| user_stub(u) }
      end

      private

      def set_target
        @target = User.find_by(handle: params[:handle])
        render json: { error: "User not found" }, status: :not_found unless @target
      end

      def user_stub(u)
        { id: u.id, name: u.name, handle: u.handle, avatar_url: (u.avatar.attached? ? url_for(u.avatar) : nil) }
      end
    end
  end
end
