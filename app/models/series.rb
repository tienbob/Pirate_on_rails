

class Series < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  has_many :movies, dependent: :destroy
  has_and_belongs_to_many :tags, dependent: :destroy
  # Optionally keep the through association if you want to show all tags from episodes as well:
  # has_many :episode_tags, through: :movies, source: :tags

  validates :title, presence: true
  validates :description, presence: true
  validates :img, presence: true, unless: -> { img_attachment.blank? && !img.is_a?(String) }

  has_one_attached :img

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
