class MealPlanEntry < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :recipe
  validates :date, presence: true
  validates :meal_type, inclusion: { in: %w[breakfast lunch dinner] }
end
