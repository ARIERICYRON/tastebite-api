module Api
  module V1
    class BookmarksController < ApplicationController
      before_action :authenticate!

      def create
        recipe = Recipe.find_by(id: params[:id])
        return render(json: { error: "Recipe not found" }, status: :not_found) unless recipe
        current_user.bookmarks.find_or_create_by(recipe: recipe)
        render json: { saved: true, recipe_id: recipe.id }, status: :created
      end

      def destroy
        bookmark = current_user.bookmarks.find_by(recipe_id: params[:id])
        bookmark&.destroy
        render json: { saved: false, recipe_id: params[:id].to_i }
      end

      def index
        recipes = current_user.saved_recipes.order(created_at: :desc)
        render json: recipes.map { |r|
          { id: r.id, title: r.title, difficulty: r.difficulty,
            time_minutes: r.time_minutes, author: { name: r.user.name, handle: r.user.handle } }
        }
      end
    end
  end
end
