class MealPlanEntry < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :recipe
  before_validation do
    self.servings ||= recipe.servings if recipe && recipe.servings.to_i.positive?
  end
  validates :servings, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }, allow_nil: true

  def planned_servings
    servings || (recipe.servings if recipe.servings.to_i.positive?)
  end

  validates :date, presence: true
  validate do
    if date && meal_plan&.week_start_date && !(meal_plan.week_start_date..meal_plan.week_start_date + 6.days).cover?(date)
      errors.add(:date, "must be within the selected week")
    end
    if recipe && recipe.status == "draft" && recipe.user_id != meal_plan&.user_id
      errors.add(:recipe, "is not available")
    end
  end
  validates :meal_type, inclusion: { in: %w[breakfast lunch dinner] }
end
