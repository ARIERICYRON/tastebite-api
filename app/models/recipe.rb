class Recipe < ApplicationRecord
  belongs_to :user
  has_many :recipe_ingredients, -> { order(position: :asc) }, dependent: :destroy
  has_many :recipe_steps, -> { order(position: :asc) }, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :recipe_reviews, dependent: :destroy
  has_one_attached :cover_image
  has_many_attached :photos

  accepts_nested_attributes_for :recipe_ingredients
  accepts_nested_attributes_for :recipe_steps

  validates :title, presence: true

  def average_rating
    recipe_reviews.average(:rating)&.round(1)
  end
end
