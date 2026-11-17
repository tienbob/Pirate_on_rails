class Movie < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  has_many :movie_tags, dependent: :destroy
  has_many :tags, through: :movie_tags
  belongs_to :series, optional: true

  validates :title, presence: true, length: { minimum: 2, maximum: 255 }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :release_date, presence: true
  validates :is_pro, inclusion: { in: [ true, false ] }
  validates :video_file, presence: true

  has_one_attached :video_file

  # Add database indexes for better performance
  scope :pro_content, -> { where(is_pro: true) }
  scope :free_content, -> { where(is_pro: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_series, ->(series_id) { where(series_id: series_id) }
  scope :published, -> { where("release_date <= ?", Date.current) }

  before_create :inherit_series_tags_and_img
  after_commit :clear_caches, on: [ :create, :update, :destroy ]

  # Elasticsearch mapping for nested tags
  settings index: { number_of_shards: 1 } do
    mappings dynamic: "false" do
      indexes :title, type: "text", analyzer: "standard"
      indexes :description, type: "text", analyzer: "standard"
      indexes :release_date, type: "date"
      indexes :is_pro, type: "boolean"
      indexes :series_id, type: "integer"
      indexes :tags, type: "nested" do
        indexes :name, type: "text", analyzer: "keyword"
      end
    end
  end

  def as_indexed_json(options = {})
    as_json(
      only: [ :title, :description, :release_date, :is_pro, :series_id ],
      include: {
        tags: { only: :name },
        series: { only: [ :title ] }
      }
    )
  end

  # Cached video URL for better performance
  def cached_video_url
    return nil unless video_file.attached?

    Rails.cache.fetch("movie_#{id}_video_url", expires_in: 1.hour) do
      Rails.application.routes.url_helpers.rails_blob_path(video_file, only_path: true)
    end
  end

  # Check if user can view this movie
  def viewable_by?(user)
    return false unless user
    return true if user.admin?
    return true unless is_pro?
    user.pro?
  end

  # Get related movies for recommendations
  def related_movies(limit: 5)
    Rails.cache.fetch("movie_#{id}_related", expires_in: 30.minutes) do
      Movie.joins(:tags)
           .where(tags: { id: tag_ids })
           .where.not(id: id)
           .where(is_pro: is_pro?)
           .distinct
           .limit(limit)
           .includes(:tags, :series)
    end
  end

  # Format duration if available
  def formatted_duration
    return "Duration not available" unless video_file.attached?

    # This would require video processing gem like streamio-ffmpeg
    # For now, return placeholder
    "Duration: TBD"
  end

  private

  def inherit_series_tags_and_img
    if series
      self.tag_ids = series.tag_ids if tag_ids.blank?
      # If using ActiveStorage for images, attach the series image if present and movie has no image
      if respond_to?(:img) && !img.attached? && series.img.attached?
        img.attach(series.img.blob)
      end
    end
  end

  def clear_caches
    Rails.cache.delete("movie_#{id}_video_url")
    Rails.cache.delete("movie_#{id}_related")
    Rails.cache.delete("series_#{series_id}_movies") if series_id

    # Clear user-specific caches (this is a simplified approach)
    Rails.cache.delete_matched("movie_#{id}_user_*")
  end
end
