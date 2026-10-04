class User < ApplicationRecord
  has_secure_password
  before_validation do
    self.email = email.to_s.strip.downcase
    self.handle = handle.to_s.strip.downcase
  end
  validates :handle, format: { with: /\A[a-z0-9_]+\z/, message: "can contain only letters, numbers and underscores" }, if: :will_save_change_to_handle?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :will_save_change_to_email?
  validates :password, length: { minimum: 8 }, allow_nil: true
  generates_token_for :password_reset, expires_in: 30.minutes do
    password_digest.last(10)
  end
  has_many :recipes, dependent: :destroy
  has_many :recipe_reviews, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :saved_recipes, through: :bookmarks, source: :recipe
  has_many :meal_plans, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one_attached :avatar

  has_many :active_follows, class_name: "Follow", foreign_key: "follower_id", dependent: :destroy
  has_many :following, through: :active_follows, source: :followed

  has_many :passive_follows, class_name: "Follow", foreign_key: "followed_id", dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :handle, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
end
