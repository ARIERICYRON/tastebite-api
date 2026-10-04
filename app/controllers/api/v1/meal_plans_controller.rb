module Api
  module V1
    class MealPlansController < ApplicationController
      before_action :authenticate!
      before_action :validate_week, except: [:remove_entry]

      def show
        plan = find_or_create_plan
        render json: plan_json(plan)
      end

      def add_entry
        plan = find_or_create_plan
        plan.with_lock do
          entry = plan.meal_plan_entries.find_or_initialize_by(date: params[:date], meal_type: params[:meal_type])
          entry.assign_attributes(recipe_id: params[:recipe_id], date: params[:date], meal_type: params[:meal_type])
          if entry.save
            render json: plan_json(plan), status: :created
          else
            render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      def remove_entry
        entry = MealPlanEntry.joins(:meal_plan)
                             .where(meal_plans: { user_id: current_user.id })
                             .find_by(id: params[:id])
        return render json: { error: "Entry not found" }, status: :not_found unless entry
        plan = entry.meal_plan
        entry.destroy
        render json: plan_json(plan)
      end

      # GET /api/v1/meal-plans/shopping-list?week=2026-07-06
      def shopping_list
        plan = find_or_create_plan

        # gather every ingredient from every planned recipe
        recipes = plan.meal_plan_entries.includes(recipe: :recipe_ingredients).map(&:recipe).select { |recipe| recipe.status != "draft" || recipe.user_id == current_user.id }
        combined = Hash.new { |h, k| h[k] = { name: nil, quantities: [] } }

        recipes.each do |recipe|
          recipe.recipe_ingredients.each do |ing|
            key = ing.name.downcase.strip
            combined[key][:name] = ing.name
            combined[key][:quantities] << "#{ing.quantity} #{ing.unit}".strip
          end
        end

        items = combined.values.map do |item|
          { name: item[:name], amounts: item[:quantities], checked: false }
        end.sort_by { |i| i[:name].downcase }

        render json: { week_start_date: plan.week_start_date, item_count: items.size, items: items }
      end

      private

      def validate_week
        @week = params[:week].present? ? Date.iso8601(params[:week]) : Date.current.beginning_of_week
        raise ArgumentError unless @week.monday?
      rescue ArgumentError, TypeError
        render json: { error: "Week must be a Monday in YYYY-MM-DD format." }, status: :unprocessable_entity
      end

      def find_or_create_plan
        current_user.with_lock { current_user.meal_plans.find_or_create_by!(week_start_date: @week) }
      end

      def plan_json(plan)
        {
          week_start_date: plan.week_start_date,
          entries: plan.meal_plan_entries.includes(:recipe).order(:date, :meal_type).map { |e|
            {
              id: e.id, date: e.date, meal_type: e.meal_type,
              recipe: e.recipe.status == "draft" && e.recipe.user_id != current_user.id ? { id: nil, title: "Recipe unavailable" } : { id: e.recipe.id, title: e.recipe.title, time_minutes: e.recipe.time_minutes, cover_image_url: (e.recipe.cover_image.attached? ? url_for(e.recipe.cover_image) : e.recipe.cover_image_url) }
            }
          }
        }
      end
    end
  end
end
