module Api
  module V1
    class RecipesController < ApplicationController
      before_action :authenticate!, only: [:create, :update, :destroy]
      before_action :set_recipe, only: [:show, :update, :destroy]

      def index
        recipes = Recipe.order(created_at: :desc)
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
        @recipe = Recipe.find_by(id: params[:id])
        render json: { error: "Recipe not found" }, status: :not_found unless @recipe
      end

      def forbid
        render json: { error: "Not your recipe" }, status: :forbidden
      end

      def recipe_params
        params.permit(
          :title, :description, :difficulty, :time_minutes, :prep_minutes, :cook_minutes, :servings, :cover_image_url, :status, :cover_image, :notes, :calories, :protein_g, :carbs_g, :fat_g, :fiber_g, photos: [],
          recipe_ingredients_attributes: [:name, :quantity, :unit, :position],
          recipe_steps_attributes: [:instruction, :position]
        )
      end

      def recipe_json(r)
        {
          id: r.id, title: r.title, description: r.description,
          difficulty: r.difficulty, time_minutes: r.time_minutes,
          prep_minutes: r.prep_minutes, cook_minutes: r.cook_minutes,
          servings: r.servings, status: r.status, notes: r.notes,
          cover_image_url: r.cover_image.attached? ? url_for(r.cover_image) : r.cover_image_url,
          photo_urls: r.photos.attached? ? r.photos.map { |p| url_for(p) } : [],
          nutrition: {
            calories: r.calories, protein_g: r.protein_g,
            carbs_g: r.carbs_g, fat_g: r.fat_g, fiber_g: r.fiber_g
          },
          average_rating: r.average_rating,
          reviews_count: r.recipe_reviews.count,
          saves_count: r.bookmarks.count,
          author: { id: r.user.id, name: r.user.name, handle: r.user.handle,
                    avatar_url: (r.user.avatar.attached? ? url_for(r.user.avatar) : nil) },
          ingredients: r.recipe_ingredients.map { |i|
            { id: i.id, name: i.name, quantity: i.quantity, unit: i.unit, position: i.position }
          },
          steps: r.recipe_steps.map { |s|
            { id: s.id, instruction: s.instruction, position: s.position }
          }
        }
      end
    end
  end
end
