module Api
  module V1
    class RecipesController < ApplicationController
      include RecipeSerialization
      before_action :authenticate!, only: [:create, :update, :destroy]
      before_action :set_recipe, only: [:show, :update, :destroy]

      def index
        recipes = Recipe.visible_to(current_user).order(created_at: :desc)
        render json: recipes.map { |r| recipe_json(r) }
      end

      def show
        render json: recipe_json(@recipe)
      end

      def create
        recipe = current_user.recipes.new(recipe_params)
        if recipe.save
          render json: recipe_json(recipe), status: :created
        else
          render json: { errors: recipe.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        return forbid unless @recipe.user_id == current_user.id
        if @recipe.update(recipe_params)
          render json: recipe_json(@recipe)
        else
          render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        return forbid unless @recipe.user_id == current_user.id
        @recipe.destroy
        head :no_content
      end

      private

      def set_recipe
        @recipe = Recipe.visible_to(current_user).find_by(id: params[:id])
        render json: { error: "Recipe not found" }, status: :not_found unless @recipe
      end

      def forbid
        render json: { error: "Not your recipe" }, status: :forbidden
      end

      def recipe_params
        params.permit(
          :title, :description, :difficulty, :time_minutes, :prep_minutes, :cook_minutes, :servings, :cover_image_url, :status, :cover_image, :notes, :calories, :protein_g, :carbs_g, :fat_g, :fiber_g, photos: [],
          recipe_ingredients_attributes: [:id, :name, :quantity, :unit, :position, :_destroy],
          recipe_steps_attributes: [:id, :instruction, :position, :_destroy]
        )
      end

    end
  end
end
