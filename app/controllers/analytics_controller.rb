class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_rate_limit
  protect_from_forgery with: :null_session
  
  def track_view
    permitted_params = params.permit(:movie_id, :watch_duration, :completed_viewing, :current_time, :total_duration, :timestamp)

  @movie = Movie.find_by(id: permitted_params[:movie_id])
    
    # Verify user can view this movie
    unless @movie.viewable_by?(current_user)
      render json: { error: 'Unauthorized' }, status: :forbidden
      return
    end
    
    Rails.logger.info "Tracking view for user: \\#{current_user.id}, movie: \\#{@movie.id}, viewed_at: \\#{Time.zone.today}"
    Rails.logger.info "Params received: \\#{permitted_params.inspect}"
    
    # Log the existing record if found
    existing_record = ViewAnalytic.find_by(user: current_user, movie: @movie, viewed_at: Time.zone.today)
    Rails.logger.info "Existing record: \\#{existing_record.inspect}" if existing_record
    
    # Create or update view analytics
    view_analytic = ViewAnalytic.find_or_initialize_by(
      user: current_user,
      movie: @movie,
      viewed_at: Time.zone.today # Use Time.zone.today for consistency
    )
    
    # Update watch duration (cumulative for the day)
    view_analytic.watch_duration = (view_analytic.watch_duration || 0) + (permitted_params[:watch_duration]&.to_i || 0)

    # Ensure completed_viewing is updated correctly
    if permitted_params[:completed_viewing].to_s == 'true'
      view_analytic.completed_viewing = true
    end

    view_analytic.ip_address = request.remote_ip
    view_analytic.user_agent = request.user_agent&.truncate(255)
    
    if view_analytic.save
      # Update movie view count cache
      Rails.cache.increment("movie_#{@movie.id}_views", 1, expires_in: 1.day)
      
      render json: { status: 'success' }
    else
      render json: { error: 'Failed to track view' }, status: :unprocessable_entity
    end
    
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Movie not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error "View tracking error: #{e.message}"
    render json: { error: 'Internal error' }, status: :internal_server_error
  end
  
  private
  
  def check_rate_limit
    rate_limit_key = "view_tracking_#{request.remote_ip}_#{current_user&.id}"
    
    if Rails.cache.read(rate_limit_key).to_i >= 60 # 60 tracking requests per minute
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
    else
      Rails.cache.increment(rate_limit_key, 1, expires_in: 1.minute)
    end
  end
end
