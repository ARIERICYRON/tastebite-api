class MealPlan < ApplicationRecord
  belongs_to :user
  has_many :shopping_items, dependent: :destroy
  validates :weekly_budget, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000 }, allow_nil: true
  validates :location, presence: true, length: { maximum: 100 }
  has_many :meal_plan_entries, dependent: :destroy
  validates :week_start_date, presence: true, uniqueness: { scope: :user_id }
end
