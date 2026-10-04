module Api
  module V1
    class MealPlansController < ApplicationController
      before_action :authenticate!
      before_action :validate_week, except: [:remove_entry, :update_entry]

      def show
        plan = find_or_create_plan
        render json: plan_json(plan)
      end

      def add_entry
        plan = find_or_create_plan
        plan.with_lock do
          entry = plan.meal_plan_entries.find_or_initialize_by(date: params[:date], meal_type: params[:meal_type])
          entry.assign_attributes(recipe_id: params[:recipe_id], date: params[:date], meal_type: params[:meal_type])
          entry.servings = params[:servings] if params.key?(:servings)
          entry.servings = nil if entry.recipe_id_changed? && !params.key?(:servings)
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

      def shopping_list
        render json: WeeklyGroceryEstimate.new(find_or_create_plan).call
      end

      def update
        plan = find_or_create_plan
        if plan.update(params.permit(:weekly_budget, :location))
          render json: WeeklyGroceryEstimate.new(plan).call
        else
          render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update_item
        plan = find_or_create_plan
        key = GroceryQuantity.key(params[:key])
        plan.with_lock do
          available = WeeklyGroceryEstimate.new(plan).call[:items].any? { |item| item[:key] == key }
          return render json: { error: "Shopping item not found" }, status: :not_found unless available
          item = plan.shopping_items.find_or_initialize_by(ingredient_key: key)
          if item.update(params.permit(:checked, :pantry, :package_price, :package_size, :package_unit))
            plan.shopping_items.reload
            render json: WeeklyGroceryEstimate.new(plan).call
          else
            render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      def import_checks
        names = params[:names]
        unless names.is_a?(Array) && names.size <= 500 && names.all? { |name| name.is_a?(String) && GroceryQuantity.key(name).present? && GroceryQuantity.key(name).length <= 255 }
          return render json: { error: "Invalid shopping checks" }, status: :unprocessable_entity
        end
        plan = find_or_create_plan
        plan.with_lock do
          names.each do |name|
            # Never overwrite checks already saved from another device.
            plan.shopping_items.find_or_create_by!(ingredient_key: GroceryQuantity.key(name)) { |item| item.checked = true }
          end
        end
        render json: WeeklyGroceryEstimate.new(plan).call
      end

      def update_entry
        entry = MealPlanEntry.joins(:meal_plan).where(meal_plans: { user_id: current_user.id }).find_by(id: params[:id])
        return render json: { error: "Entry not found" }, status: :not_found unless entry
        if entry.update(params.permit(:servings))
          render json: plan_json(entry.meal_plan)
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
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
          week_start_date: plan.week_start_date, weekly_budget: plan.weekly_budget&.to_f, location: plan.location, currency: "CAD",
          entries: plan.meal_plan_entries.includes(:recipe).order(:date, :meal_type).map { |e|
            {
              id: e.id, date: e.date, meal_type: e.meal_type, servings: e.planned_servings&.to_f,
              recipe: e.recipe.status == "draft" && e.recipe.user_id != current_user.id ? { id: nil, title: "Recipe unavailable" } : { id: e.recipe.id, title: e.recipe.title, time_minutes: e.recipe.time_minutes, cover_image_url: (e.recipe.cover_image.attached? ? url_for(e.recipe.cover_image) : e.recipe.cover_image_url) }
            }
          }
        }
      end
    end
  end
end
