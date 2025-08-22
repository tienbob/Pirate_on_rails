class MoviesController < ApplicationController
  include Searchable
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :destroy]
  before_action :set_movie, only: [:edit, :destroy, :show]
  before_action :check_rate_limit, only: [:show, :search]
  
  # Cache frequently accessed data
  CACHE_EXPIRY = 1.hour

  # Only allow admins to perform certain actions
  def require_admin
    unless current_user&.admin?
      redirect_to series_index_path, alert: 'You are not authorized to perform this action.'
    end
  end

  # Actions for the MovieController
  def edit
    authorize @movie
  end

  def destroy
    authorize @movie
    parent_series = @movie.series
    
    ActiveRecord::Base.transaction do
      @movie.destroy!
      # Clear related caches
      Rails.cache.delete("movie_#{@movie.id}")
      Rails.cache.delete("series_#{parent_series.id}_movies")
    end
    
    redirect_to series_path(parent_series), notice: 'Episode was successfully deleted.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to series_path(parent_series), alert: "Failed to delete episode: #{e.message}"
  end

  def show
    # Use caching for better performance
    cache_key = "movie_#{params[:id]}_user_#{current_user.id}_#{current_user.role}"
    
    @movie = Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      movie = policy_scope(Movie)
                .includes(:tags, :series, video_file_attachment: :blob)
                .find_by(id: params[:id])
      authorize movie
      movie
    end
    
    # Track view analytics (async) - with Redis error handling
    begin
      TrackViewJob.perform_later(current_user.id, @movie.id) if current_user
    rescue Redis::CannotConnectError, Redis::TimeoutError => e
      Rails.logger.warn "Redis connection failed for TrackViewJob: #{e.message}"
      # Continue without tracking - don't break the user experience
    end
    
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Movie not found or you don't have permission to view it."
    redirect_to series_index_path
  rescue Pundit::NotAuthorizedError
    flash[:alert] = "This content is for Pro users only. Please upgrade your account."
    redirect_to upgrade_payment_path
  end


  def new
    unless params[:series_id].present? && Series.exists?(params[:series_id])
      redirect_to series_index_path, alert: 'You must select a series before adding an episode.'
      return
    end
    @movie = Movie.new(series_id: params[:series_id])
    authorize @movie
  end

  def create
    unless params[:movie][:series_id].present? && Series.exists?(params[:movie][:series_id])
      redirect_to series_index_path, alert: 'You must select a series before adding an episode.'
      return
    end
    
    @movie = Movie.new(movie_params)
    authorize @movie
    
    ActiveRecord::Base.transaction do
      if @movie.save
        # Handle tag associations efficiently
        handle_tag_associations(@movie, params[:movie][:tag_ids] || [])
        
        # Clear relevant caches
        Rails.cache.delete("series_#{@movie.series_id}_movies")
        
        redirect_to @movie, notice: 'Movie was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Failed to create movie: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def search
    # Implement rate limiting for search
    rate_limit_key = "search_#{request.remote_ip}_#{current_user&.id}"
    
    if Rails.cache.read(rate_limit_key).to_i >= 30 # 30 searches per minute
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      return
    end
    
    Rails.cache.increment(rate_limit_key, 1, expires_in: 1.minute)
    
    # Use caching for search results
    search_cache_key = "search_#{Digest::MD5.hexdigest(params.to_query)}_#{current_user.role}"
    
    @movies = Rails.cache.fetch(search_cache_key, expires_in: 10.minutes) do
      movies = search_movies(params)
      policy_scope(movies).includes(:tags, :series, video_file_attachment: :blob)
                          .page(params[:page]).per(12)
    end
    
    if request.headers['Turbo-Frame']
      render partial: 'movies/results', locals: { movies: @movies }
    else
      render :index
    end
  end

  private

  def movie_params
    params.require(:movie).permit(:title, :description, :release_date, :is_pro, :video_file, :series_id)
  end

  def set_movie
    @movie = Movie.includes(:series).find_by(id: params[:id])
  end
  
  def check_rate_limit
    rate_limit_key = "movie_views_#{request.remote_ip}_#{current_user&.id}"
    
    if Rails.cache.read(rate_limit_key).to_i >= 100 # 100 views per hour
      flash[:alert] = 'Too many requests. Please try again later.'
      redirect_to series_index_path
    else
      Rails.cache.increment(rate_limit_key, 1, expires_in: 1.hour)
    end
  end
  
  def handle_tag_associations(movie, tag_ids)
    return unless movie.series.present?
    
    movie_tags = Tag.where(id: tag_ids)
    series_tags = movie.series.tags
    all_tags = (series_tags + movie_tags).uniq
    
    movie.tags = all_tags
    
    # Add new tags to series
    new_tags = movie_tags - series_tags
    movie.series.tags << new_tags unless new_tags.empty?
  end 
end
