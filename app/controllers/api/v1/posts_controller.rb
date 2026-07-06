module Api
  module V1
    class PostsController < ApplicationController
      before_action :authenticate!, only: [:create, :destroy]

      # GET /api/v1/posts
      def index
        posts = Post.order(created_at: :desc)
        render json: posts.map { |p| post_json(p) }
      end

      # GET /api/v1/posts/:id
      def show
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        render json: post_json(post)
      end

      # POST /api/v1/posts
      def create
        post = current_user.posts.new(post_params)
        if post.save
          render json: post_json(post), status: :created
        else
          render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/posts/:id
      def destroy
        post = Post.find_by(id: params[:id])
        return render json: { error: "Post not found" }, status: :not_found unless post
        return render json: { error: "Not your post" }, status: :forbidden unless post.user_id == current_user.id
        post.destroy
        head :no_content
      end

      private

      def post_params
        params.permit(:caption, :image_url, :recipe_id)
      end

      def post_json(p)
        {
          id: p.id, caption: p.caption, image_url: p.image_url,
          created_at: p.created_at,
          author: { id: p.user.id, name: p.user.name, handle: p.user.handle },
          recipe: p.recipe && { id: p.recipe.id, title: p.recipe.title }
        }
      end
    end
  end
end
