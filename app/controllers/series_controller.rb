require_dependency "searchable"
class SeriesController < ApplicationController
  include Searchable
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy]
  after_action :verify_authorized, except: [:index, :show]
  after_action :verify_policy_scoped, only: [:index]

  # Only allow admins to perform certain actions
  def require_admin
    unless current_user && current_user.admin?
      redirect_to series_index_path, alert: 'You are not authorized to perform this action.'
    end
  end

  # Actions for the SeriesController
  def index
    page = (params[:page] || 1).to_i
    per_page = 8

    # Treat empty search params as no search
    q_blank = !params[:q].present? || params[:q].strip == ""
    tags_blank = !params[:tags].present? || Array(params[:tags]).all? { |t| t.blank? }

    if params[:search_type] == 'episode' && (!q_blank || !tags_blank)
      movies = search_movies(params)
      @movies = policy_scope(movies).page(page).per(per_page)
      @series = [] # Prevent nil error in _results.html.erb
      respond_to do |format|
        format.html { render :index }
        format.turbo_stream { render partial: 'movies/results', locals: { movies: @movies } }
      end
    elsif (!q_blank || !tags_blank)
      # Efficient search with proper pagination - avoid loading all records
      search_scope = policy_scope(search_series(params))

      # Apply ordering and pagination directly to the relation
      @series = search_scope
        .order(updated_at: :desc)
        .page(page)
        .per(per_page)

      # Initialize empty hash for image URLs - we'll populate in the view as needed
      @series_image_urls = {}
    else
      # Use optimized queries - REMOVED expensive eager loading of all movies
      series_scope = policy_scope(Series.all)

      # Cache total count separately to avoid N+1 queries
      total_count = Rails.cache.fetch("series_total_count", expires_in: 30.minutes) do
        series_scope.count
      end

      # Get paginated series with minimal necessary eager loading
      @series = series_scope
        .order(updated_at: :desc)
        .page(page)
        .per(per_page)

      # Set total count for Kaminari pagination
      @series.instance_variable_set(:@total_count, total_count)

      # Initialize empty hash for image URLs - we'll populate in the view as needed
      @series_image_urls = {}
    end
  end

  def show
    # Use cached query to avoid repeated database hits - simplified includes
    cache_key = "series_#{params[:id]}_with_tags_only"
    @series = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      Series.includes(:tags).find(params[:id])  # Removed movies eager loading
    end
    
    # Optimize episodes query with cached pagination data
    page = (params[:page] || 1).to_i
    per_page = 8
    
    # Cache the total episodes count
    total_episodes_key = "series_#{@series.id}_total_episodes"
    total_episodes = Rails.cache.fetch(total_episodes_key, expires_in: 30.minutes) do
      @series.movies.count
    end
    
    # Get paginated episodes efficiently - minimal includes
    episodes_start = Time.current
    @episodes = @series.movies
      .select(:id, :title, :description, :release_date, :is_pro, :series_id)  # Select only needed columns
      .order(:release_date)
      .page(page)
      .per(per_page)
      
    # Manually set total count to avoid extra queries
    @episodes.instance_variable_set(:@total_count, total_episodes)
    Rails.logger.info "Episodes query took: #{((Time.current - episodes_start) * 1000).round(2)}ms"
  end

  def new
    authorize Series
    @series = Series.new
  end

  def create
    authorize Series
    @series = Series.new(series_params)
    if @series.save
      expire_series_cache(@series)
      expire_series_index_cache
      redirect_to @series, notice: 'Series was successfully created.'
    else
      render :new
    end
  end

  def edit
    authorize Series
    @series = Series.find(params[:id])
  end

  def update
    authorize Series
    @series = Series.find(params[:id])
    if @series.update(series_params)
      # After updating series tags, update all its movies to have the full set of series tags (plus any unique movie tags)
      @series.movies.find_each do |movie|
        movie.tags = (movie.tags + @series.tags).uniq
        # Also, ensure the series gets any unique tags from its movies
        new_tags = movie.tags - @series.tags
        @series.tags << new_tags unless new_tags.empty?
      end
      expire_series_cache(@series)
      expire_series_index_cache
      redirect_to @series, notice: 'Series was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize Series
    @series = Series.find(params[:id])
    expire_series_cache(@series)
    expire_series_index_cache
    @series.destroy
    redirect_to series_index_path, notice: 'Series was successfully deleted.'
  end

  private

  # Expire caches when series data changes
  def expire_series_cache(series)
    # Clear series count cache
    Rails.cache.delete("series_total_count")
    
    # Clear series-specific caches (updated cache key)
    Rails.cache.delete("series_#{series.id}_with_tags_only")
    Rails.cache.delete("series_#{series.id}_with_associations")  # Keep for backward compatibility
    Rails.cache.delete("series_#{series.id}_image_url")
    Rails.cache.delete("series_#{series.id}_image_url_v2")
    Rails.cache.delete("series_#{series.id}_image_url_v3")
    Rails.cache.delete("series_#{series.id}_image_url_v4")
    Rails.cache.delete("series_#{series.id}_image_url_v5")
    Rails.cache.delete("series_#{series.id}_total_episodes")
    
    # Clear view fragment caches
    Rails.cache.delete("series_#{series.id}_show_v2")
    
    # Clear ActiveStorage blob URL caches if image is attached
    if series.img.attached?
      Rails.cache.delete_matched("blob_url_#{series.img.key}_*")
    end
    
    # Clear paginated episode caches (use cached count to avoid DB query)
    cached_count = Rails.cache.read("series_#{series.id}_total_episodes") || 0
    total_pages = (cached_count / 8.0).ceil
    (1..[total_pages, 1].max).each do |page|
      Rails.cache.delete("series_#{series.id}_episodes_page_#{page}")
      Rails.cache.delete("series_#{series.id}_episodes_page_#{page}_v2")
      Rails.cache.delete("series_#{series.id}_episodes_page_#{page}_v3")
    end
  end

  # Expire index cache for current and adjacent pages
  def expire_series_index_cache
    # Clear series count cache
    Rails.cache.delete("series_total_count")
    
    # Clear cached pagination data
    (1..10).each do |page|
      Rails.cache.delete(["series_index", page])
      Rails.cache.delete(["series_index_ids", page])
    end
  end

  def series_params
    params.require(:series).permit(:title, :description, :img, tag_ids: [])
  end
end