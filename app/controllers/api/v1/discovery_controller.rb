module Api
  module V1
    class DiscoveryController < ApplicationController
      # GET /api/v1/search?q=ramen&difficulty=Easy&max_time=30
      def search
        recipes = Recipe.all

        if params[:q].present?
          term = "%#{params[:q].downcase}%"
          recipes = recipes.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", term, term)
        end

        recipes = recipes.where(difficulty: params[:difficulty]) if params[:difficulty].present?
        recipes = recipes.where("time_minutes <= ?", params[:max_time]) if params[:max_time].present?

        recipes = recipes.order(created_at: :desc)
        render json: { count: recipes.count, results: recipes.map { |r| card(r) } }
      end

      # GET /api/v1/explore/trending
      def trending
        recipes = Recipe
          .left_joins(:bookmarks)
          .group("recipes.id")
          .order("COUNT(bookmarks.id) DESC, recipes.created_at DESC")
          .limit(10)
        render json: recipes.map { |r| card(r) }
      end

      private

      def card(r)
        {
          id: r.id, title: r.title, difficulty: r.difficulty,
          time_minutes: r.time_minutes, saves_count: r.bookmarks.count,
          author: { name: r.user.name, handle: r.user.handle }
        }
      end
    end
  end
end
