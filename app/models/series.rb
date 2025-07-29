class Series < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  has_many :movies, dependent: :destroy
  has_many :tags, through: :movies

  validates :title, presence: true
  validates :description, presence: true
  validates :img, presence: true

  # Elasticsearch mapping for nested tags
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: 'text'
      indexes :description, type: 'text'
      indexes :img, type: 'text'
      indexes :tags, type: 'nested' do
        indexes :name, type: 'text'
      end
    end
  end

  def as_indexed_json(options = {})
    as_json(
      only: [:title, :description, :img],
      include: { tags: { only: :name } }
    )
  end
end
