class TrackViewJob < ApplicationJob
  queue_as :default

  def perform(user_id, movie_id)
    user = User.find_by(id: user_id)
    movie = Movie.find_by(id: movie_id)

    return unless user && movie

    # Create view analytics record
    ViewAnalytic.create!(
      user: user,
      movie: movie,
      viewed_at: Time.current,
      ip_address: nil # Would need to pass from controller if needed
    )

    # Update movie view count
    Rails.cache.increment("movie_#{movie_id}_views", 1, expires_in: 1.day)

    Rails.logger.info "View tracked: User #{user.email} viewed movie #{movie.title}"
  rescue StandardError => e
    Rails.logger.error "TrackViewJob failed: #{e.message}"
  end
end
