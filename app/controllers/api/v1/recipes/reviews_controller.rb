module Api
  module V1
    module Recipes
      class ReviewsController < ApplicationController
        before_action :authenticate!, only: [:create, :destroy]
        before_action :set_recipe

        def index
          render json: @recipe.recipe_reviews.order(created_at: :desc).map { |r| review_json(r) }
        end

        def create
          review = @recipe.recipe_reviews.find_or_initialize_by(user: current_user)
          review.body = params[:body]
          review.rating = params[:rating]
          if review.save
            Notification.notify(recipient: @recipe.user, actor: current_user,
                                action: "review", notifiable: @recipe) if @recipe.user
            render json: review_json(review), status: :created
          else
            render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          review = @recipe.recipe_reviews.find_by(id: params[:id])
          return render json: { error: "Review not found" }, status: :not_found unless review
          return render json: { error: "Not your review" }, status: :forbidden unless review.user_id == current_user.id
          review.destroy!
          head :no_content
        end

        private

        def set_recipe
          @recipe = Recipe.visible_to(current_user).find_by(id: params[:recipe_id])
          render json: { error: "Recipe not found" }, status: :not_found unless @recipe
        end

        def review_json(r)
          {
            id: r.id, body: r.body, rating: r.rating, created_at: r.created_at,
            author: { id: r.user.id, name: r.user.name, handle: r.user.handle,
                      avatar_url: (r.user.avatar.attached? ? url_for(r.user.avatar) : nil) }
          }
        end
      end
    end
  end
end
