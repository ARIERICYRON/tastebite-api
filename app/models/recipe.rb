class Recipe < ApplicationRecord
  belongs_to :user, optional: true
  scope :community, -> { where(provider: nil) }
  validates :user, presence: true, unless: :provider_recipe?
  validates :provider, inclusion: { in: %w[themealdb wikibooks] }, allow_nil: true
  validates :provider_id, presence: true, if: :provider_recipe?
  validate do
    errors.add(:user, "cannot own shared provider content") if provider_recipe? && user_id.present?
  end

  def provider_recipe?
    provider.present?
  end
  has_many :posts, dependent: :nullify
  has_many :meal_plan_entries, dependent: :destroy
  scope :published, -> { where("recipes.status IS DISTINCT FROM 'draft'") }
  scope :visible_to, ->(viewer) { where("recipes.status IS DISTINCT FROM 'draft' OR recipes.user_id = ?", viewer&.id) }
  has_many :recipe_ingredients, -> { order(position: :asc) }, dependent: :destroy
  has_many :recipe_steps, -> { order(position: :asc) }, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :recipe_reviews, dependent: :destroy
  has_one_attached :cover_image
  has_many_attached :photos

  accepts_nested_attributes_for :recipe_ingredients, allow_destroy: true
  accepts_nested_attributes_for :recipe_steps, allow_destroy: true

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published] }, allow_blank: true, if: :will_save_change_to_status?

  def average_rating
    recipe_reviews.average(:rating)&.round(1)&.to_f
  end
end
