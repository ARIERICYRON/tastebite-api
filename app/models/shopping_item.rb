class ShoppingItem < ApplicationRecord
  belongs_to :meal_plan
  validates :ingredient_key, presence: true, length: { maximum: 255 }, uniqueness: { scope: :meal_plan_id }
  validates :package_price, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000, message: "must be a non-negative CAD amount below one billion" }, allow_nil: true
  validates :package_size, numericality: { greater_than: 0, less_than: 1_000_000_000 }, allow_nil: true
  validates :package_unit, length: { maximum: 40 }
end
