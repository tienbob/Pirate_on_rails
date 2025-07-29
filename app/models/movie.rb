
class Movie < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  has_many :movie_tags, dependent: :destroy
  has_many :tags, through: :movie_tags
  belongs_to :series, optional: true

  validates :title, presence: true
  validates :description, presence: true
  validates :release_date, presence: true
  validates :is_pro, inclusion: { in: [true, false] }
  validates :video_file, presence: true
  has_one_attached :video_file

  before_create :inherit_series_tags_and_img

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

  private
  def inherit_series_tags_and_img
    if series
      self.tag_ids = series.tag_ids if self.tag_ids.blank?
      # If using ActiveStorage for images, attach the series image if present and movie has no image
      if self.respond_to?(:img) && self.img.blank? && series.img.attached?
        self.img.attach(series.img.blob)
      end
    end
  end
end
