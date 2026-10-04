module Api
  module V1
    class DiscoveryController < ApplicationController
      include RecipeSerialization
      # GET /api/v1/search?q=ramen&difficulty=Easy&max_time=30
      def search
        recipes = Recipe.published

        if params[:q].present?
          term = "%#{params[:q].downcase}%"
          recipes = recipes.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", term, term)
        end

        recipes = recipes.where(difficulty: params[:difficulty]) if params[:difficulty].present?
        recipes = recipes.where("time_minutes <= ?", params[:max_time]) if params[:max_time].present?

        recipes = recipes.order(created_at: :desc)
        users = params[:q].present? ? User.where("LOWER(name) LIKE ? OR LOWER(handle) LIKE ?", term, term).limit(20) : []
        render json: { count: recipes.count, results: recipes.map { |r| card(r) }, users: users.map { |u| { id: u.id, name: u.name, handle: u.handle } } }
      end

      # GET /api/v1/explore/trending
      def trending
        recipes = Recipe.published
          .left_joins(:bookmarks)
          .group("recipes.id")
          .order("COUNT(bookmarks.id) DESC, recipes.created_at DESC")
          .limit(10)
        render json: recipes.map { |r| card(r) }
      end

      private

      def card(r)
        recipe_json(r)
      end
    end
  end
end
