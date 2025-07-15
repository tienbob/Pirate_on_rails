class Movie < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  has_many :movie_tags
  has_many :tags, through: :movie_tags

  validates :title, presence: true
  validates :description, presence: true
  validates :release_date, presence: true
  validates :is_pro, inclusion: { in: [true, false] }
  validates :video_file, presence: true

  has_one_attached :video_file
  belongs_to :user

end
