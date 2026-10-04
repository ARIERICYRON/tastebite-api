module Api
  module V1
    class ProviderDiscoveryController < ApplicationController
      include RecipeSerialization
      before_action :authenticate!
      rescue_from TheMealDb::Unavailable, with: :unavailable
      rescue_from TheMealDb::NotFound do |error|
        render json: { error: error.message }, status: :not_found
      end
      rescue_from TheMealDb::InvalidQuery do |error|
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def catalogs
        render json: TheMealDb.new.catalogs
      end

      def index
        results = TheMealDb.new.search(**params.permit(:q, :category, :cuisine, :ingredient).to_h.symbolize_keys)
        render json: { results: results, limit: TheMealDb::LIMIT, default_first_letter: params.values_at(:q, :category, :cuisine, :ingredient).all?(&:blank?) ? "A" : nil }
      end

      def show
        recipe = Recipe.find_by(provider: "themealdb", provider_id: params[:id])
        begin
          detail = TheMealDb.new.detail(params[:id])
        rescue TheMealDb::Unavailable, TheMealDb::NotFound
          raise unless recipe
          detail = recipe.provider_metadata.symbolize_keys.merge(ingredients: recipe.recipe_ingredients.map { |i| i.attributes.symbolize_keys.slice(:name, :quantity, :unit, :original_measurement, :quantity_issue, :position) }, snapshot_warning: "The provider is unavailable. Showing the saved recipe snapshot.")
        end
        if recipe
          warning = detail[:snapshot_warning]
          detail = recipe.provider_metadata.symbolize_keys.merge(ingredients: recipe.recipe_ingredients.map { |i| i.attributes.symbolize_keys.slice(:name, :quantity, :unit, :original_measurement, :quantity_issue, :position) })
          detail[:snapshot_warning] = warning || "Showing the shared imported snapshot used by saved recipes and meal plans."
        end
        render json: detail.merge(imported_recipe_id: recipe&.id, saved: recipe ? current_user.saved_recipes.exists?(id: recipe.id) : false)
      end

      def import
        recipe = ProviderRecipeImport.call(params[:id])
        current_user.bookmarks.find_or_create_by!(recipe: recipe) unless params[:save] == false
        render json: recipe_json(recipe), status: :created
      end

      private
      def unavailable(error)
        render json: { error: error.message }, status: :service_unavailable
      end
    end
  end
end
