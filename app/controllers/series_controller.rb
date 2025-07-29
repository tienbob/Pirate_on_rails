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
    if params[:search_type] == 'episode' && (params[:q].present? || params[:tags].present?)
      movies = search_movies(params)
      @movies = movies.page(page).per(per_page)
      respond_to do |format|
        format.html { render :index }
        format.turbo_stream { render partial: 'movies/results', locals: { movies: @movies } }
      end
    elsif params[:q].present? || params[:tags].present?
      @series = policy_scope(search_series(params))
      @series = @series.order(updated_at: :desc)
      @series = Kaminari.paginate_array(@series, total_count: @series.size).page(page).per(per_page)
    else
      series_scope = policy_scope(Series.includes(:movies, :tags))
      if page <= 3
        cached_ids = Rails.cache.fetch(["series_index_ids", page], expires_in: 60.minutes) do
          series_scope.order(updated_at: :desc).page(page).per(per_page).pluck(:id)
        end
        @series = series_scope.where(id: cached_ids).order(updated_at: :desc)
        @series = Kaminari.paginate_array(@series, total_count: series_scope.count).page(page).per(per_page)
      else
        @series = series_scope.order(updated_at: :desc).page(page).per(per_page)
      end
    end
  end

  def show
    @series = Series.includes(:movies, :tags).find(params[:id])
    @episodes = @series.movies.order(:release_date).page(params[:page]).per(8)
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

  # Expire show page cache for all paginated episode pages of this series
  def expire_series_cache(series)
    total_pages = (series.movies.count / 8.0).ceil
    (1..[total_pages, 1].max).each do |page|
      Rails.cache.delete([series, page])
    end
  end

  # Expire index cache for current and two adjacent pages
  def expire_series_index_cache
    # Try to expire for first 5 pages (or more if needed)
    (1..5).each do |page|
      Rails.cache.delete(["series_index", page])
    end
  end

  def series_params
    params.require(:series).permit(:title, :description, :img, tag_ids: [])
  end
end