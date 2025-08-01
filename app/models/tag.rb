class Tag < ApplicationRecord
  has_many :movie_tags
  has_many :movies, through: :movie_tags

  validates :name, presence: true, uniqueness: true
end
