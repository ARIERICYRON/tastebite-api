module Api
  module V1
    class BookmarksController < ApplicationController
      include RecipeSerialization
      before_action :authenticate!

      def create
        recipe = Recipe.visible_to(current_user).find_by(id: params[:id])
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
        render json: recipes.visible_to(current_user).map { |r| recipe_json(r) }
      end
    end
  end
end
