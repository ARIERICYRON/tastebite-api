class MealPlan < ApplicationRecord
  belongs_to :user
  has_many :meal_plan_entries, dependent: :destroy
  validates :week_start_date, presence: true, uniqueness: { scope: :user_id }
end
