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
        render json: discovery_catalog.catalogs
      end

      def index
        filters = params.permit(:q, :category, :cuisine, :ingredient).to_h.symbolize_keys
        catalog = discovery_catalog
        results = catalog.search(**filters)
        default_first_letter = "A" if catalog.is_a?(TheMealDb) && filters.values.all?(&:blank?)
        render json: { results: results, limit: catalog.class::LIMIT, default_first_letter: default_first_letter }
      end

      def show
        if curated_id?
          recipe = WikibooksCatalog.find!(params[:id])
          detail = snapshot(recipe)
        else
          recipe = Recipe.find_by(provider: "themealdb", provider_id: params[:id])
          detail = legacy_detail(recipe)
        end
        render json: detail.merge(imported_recipe_id: recipe&.id, saved: recipe ? current_user.saved_recipes.exists?(id: recipe.id) : false)
      end

      def import
        recipe = curated_id? ? WikibooksCatalog.find!(params[:id]) : ProviderRecipeImport.call(params[:id])
        current_user.bookmarks.find_or_create_by!(recipe: recipe) unless params[:save] == false
        render json: recipe_json(recipe), status: :created
      end

      private

      def discovery_catalog
        params[:provider] == "themealdb" ? TheMealDb.new : WikibooksCatalog.new
      end

      def curated_id?
        WikibooksCatalog::ID_PATTERN.match?(params[:id].to_s)
      end

      def legacy_detail(recipe)
        detail = TheMealDb.new.detail(params[:id])
        return detail unless recipe

        snapshot(recipe).merge(snapshot_warning: "Showing the shared imported snapshot used by saved recipes and meal plans.")
      rescue TheMealDb::Unavailable, TheMealDb::NotFound
        raise unless recipe

        snapshot(recipe).merge(snapshot_warning: "The provider is unavailable. Showing the saved recipe snapshot.")
      end

      def snapshot(recipe)
        ingredients = recipe.recipe_ingredients.map do |ingredient|
          ingredient.attributes.symbolize_keys.slice(:name, :quantity, :unit, :original_measurement, :quantity_issue, :position)
        end
        recipe.provider_metadata.symbolize_keys.merge(ingredients: ingredients)
      end

      def unavailable(error)
        render json: { error: error.message }, status: :service_unavailable
      end
    end
  end
end
