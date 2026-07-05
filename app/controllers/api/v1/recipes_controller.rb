module Api
  module V1
    class RecipesController < ApplicationController
      before_action :authenticate!, only: [:create, :update, :destroy]
      before_action :set_recipe, only: [:show, :update, :destroy]

      # GET /api/v1/recipes  — list all recipes
      def index
        recipes = Recipe.order(created_at: :desc)
        render json: recipes.map { |r| recipe_json(r) }
      end

      # GET /api/v1/recipes/:id  — one recipe
      def show
        render json: recipe_json(@recipe)
      end

      # POST /api/v1/recipes  — create (must be logged in)
      def create
        recipe = current_user.recipes.new(recipe_params)
        if recipe.save
          render json: recipe_json(recipe), status: :created
        else
          render json: { errors: recipe.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/recipes/:id  — update (owner only)
      def update
        return forbid unless @recipe.user_id == current_user.id
        if @recipe.update(recipe_params)
          render json: recipe_json(@recipe)
        else
          render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/recipes/:id  — delete (owner only)
      def destroy
        return forbid unless @recipe.user_id == current_user.id
        @recipe.destroy
        head :no_content
      end

      private

      def set_recipe
        @recipe = Recipe.find_by(id: params[:id])
        render json: { error: "Recipe not found" }, status: :not_found unless @recipe
      end

      def forbid
        render json: { error: "Not your recipe" }, status: :forbidden
      end

      def recipe_params
        params.permit(:title, :description, :difficulty, :time_minutes, :servings, :cover_image_url, :status)
      end

      def recipe_json(r)
        {
          id: r.id, title: r.title, description: r.description,
          difficulty: r.difficulty, time_minutes: r.time_minutes,
          servings: r.servings, cover_image_url: r.cover_image_url,
          status: r.status,
          author: { id: r.user.id, name: r.user.name, handle: r.user.handle }
        }
      end
    end
  end
end