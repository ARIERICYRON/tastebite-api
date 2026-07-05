class User < ApplicationRecord
  has_secure_password
  has_many :recipes, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :handle, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
end