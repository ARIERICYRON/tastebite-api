class User < ApplicationRecord
  has_secure_password
  has_many :recipes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :saved_recipes, through: :bookmarks, source: :recipe

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :handle, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
end
