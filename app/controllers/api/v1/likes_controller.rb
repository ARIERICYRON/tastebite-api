module Api
  module V1
    class LikesController < ApplicationController
      before_action :authenticate!

      def create
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        current_user.likes.find_or_create_by(post: post)
        Notification.notify(recipient: post.user, actor: current_user, action: "like", notifiable: post)
        render json: { liked: true, post_id: post.id, likes_count: post.likes.count }, status: :created
      end

      def destroy
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        current_user.likes.find_by(post: post)&.destroy
        render json: { liked: false, post_id: post.id, likes_count: post.likes.count }
      end
    end
  end
end
