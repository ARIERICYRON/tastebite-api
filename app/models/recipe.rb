class Recipe < ApplicationRecord
  belongs_to :user
  has_many :recipe_ingredients, -> { order(position: :asc) }, dependent: :destroy
  has_many :recipe_steps, -> { order(position: :asc) }, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_one_attached :cover_image

  accepts_nested_attributes_for :recipe_ingredients
  accepts_nested_attributes_for :recipe_steps

  validates :title, presence: true
end
