class RecipeReview < ApplicationRecord
  belongs_to :user
  belongs_to :recipe

  validates :body, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :user_id, uniqueness: { scope: :recipe_id }
end
