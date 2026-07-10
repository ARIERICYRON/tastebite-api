module Api
  module V1
    class PostsController < ApplicationController
      before_action :authenticate!, only: [:create, :destroy]
      before_action :set_current_user_if_present, only: [:index, :show]

      def index
        posts = Post.order(created_at: :desc)
        render json: posts.map { |p| post_json(p) }
      end

      def show
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        render json: post_json(post)
      end

      def create
        post = current_user.posts.new(post_params)
        if post.save
          render json: post_json(post), status: :created
        else
          render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        return render json: { error: "Not your post" }, status: :forbidden unless post.user_id == current_user.id
        post.destroy
        head :no_content
      end

      private

      # index/show are public, but we still want to know who's asking if they're logged in
      def set_current_user_if_present
        @maybe_user = current_user
      rescue
        @maybe_user = nil
      end

      def post_params
        params.permit(:caption, :image_url, :recipe_id)
      end

      def post_json(p)
        viewer = @maybe_user || (respond_to?(:current_user, true) ? current_user : nil)
        {
          id: p.id, caption: p.caption, image_url: p.image_url,
          created_at: p.created_at,
          author: { id: p.user.id, name: p.user.name, handle: p.user.handle },
          recipe: p.recipe && { id: p.recipe.id, title: p.recipe.title },
          likes_count: p.likes.count,
          comments_count: p.comments.count,
          liked: viewer ? p.likes.exists?(user_id: viewer.id) : false
        }
      end
    end
  end
end
