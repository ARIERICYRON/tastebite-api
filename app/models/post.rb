class Post < ApplicationRecord
  belongs_to :user
  belongs_to :recipe, optional: true

  has_many :likes, dependent: :destroy
  has_many :comments, -> { order(created_at: :asc) }, dependent: :destroy

  validates :caption, presence: true
end
