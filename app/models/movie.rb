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

  # Elasticsearch mapping for nested tags
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: 'text'
      indexes :description, type: 'text'
      indexes :release_date, type: 'date'
      indexes :is_pro, type: 'boolean'
      indexes :tags, type: 'nested' do
        indexes :name, type: 'text'
      end
    end
  end

  def as_indexed_json(options = {})
    as_json(
      only: [:title, :description, :release_date, :is_pro],
      include: { tags: { only: :name } }
    )
  end
end
