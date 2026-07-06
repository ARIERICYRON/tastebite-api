class User < ApplicationRecord
  has_secure_password
  has_many :recipes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :saved_recipes, through: :bookmarks, source: :recipe

  has_many :active_follows, class_name: "Follow", foreign_key: "follower_id", dependent: :destroy
  has_many :following, through: :active_follows, source: :followed

  has_many :passive_follows, class_name: "Follow", foreign_key: "followed_id", dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :handle, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
end
