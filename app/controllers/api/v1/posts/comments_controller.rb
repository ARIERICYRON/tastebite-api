module Api
  module V1
    module Posts
      class CommentsController < ApplicationController
        before_action :authenticate!, only: [:create]

        def index
          post = Post.find_by(id: params[:post_id])
          return render json: { error: "Post not found" }, status: :not_found unless post
          render json: post.comments.map { |c| comment_json(c) }
        end

        def create
          post = Post.find_by(id: params[:post_id])
          return render json: { error: "Post not found" }, status: :not_found unless post
          comment = post.comments.new(body: params[:body], user: current_user)
          if comment.save
            Notification.notify(recipient: post.user, actor: current_user, action: "comment", notifiable: post)
            render json: comment_json(comment), status: :created
          else
            render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def comment_json(c)
          {
            id: c.id, body: c.body, created_at: c.created_at,
            author: { id: c.user.id, name: c.user.name, handle: c.user.handle }
          }
        end
      end
    end
  end
end
