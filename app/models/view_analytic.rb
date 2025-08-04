class ViewAnalytic < ApplicationRecord
  belongs_to :user
  belongs_to :movie

  validates :viewed_at, presence: true
  validates :watch_duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :completed, -> { where(completed_viewing: true) }
  scope :recent, -> { order(viewed_at: :desc) }
  scope :for_movie, ->(movie) { where(movie: movie) }
  scope :for_user, ->(user) { where(user: user) }
  scope :this_week, -> { where(viewed_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(viewed_at: 1.month.ago..Time.current) }

  # Analytics methods
  def self.popular_movies(limit: 10)
    joins(:movie)
      .group('movies.id', 'movies.title')
      .order('COUNT(*) DESC')
      .limit(limit)
      .pluck('movies.title', 'COUNT(*)')
  end

  def self.user_engagement_stats(user)
    where(user: user).group_by_day(:viewed_at).count
  end

  def completion_rate
    return 0 unless watch_duration && movie.respond_to?(:duration) && movie.duration
    
    (watch_duration.to_f / movie.duration * 100).round(2)
  end
end
