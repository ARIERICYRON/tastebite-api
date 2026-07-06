class Post < ApplicationRecord
  belongs_to :user
  belongs_to :recipe, optional: true

  validates :caption, presence: true
end
