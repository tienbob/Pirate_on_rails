class MoviesController < ApplicationController
  include Searchable
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :destroy]
  before_action :set_movie, only: [:edit, :destroy, :show]
  # Only allow admins to perform certain actions
  def require_admin
    unless current_user && current_user.admin?
      redirect_to movies_path, alert: 'You are not authorized to perform this action.'
    end
  end

  # Actions for the MovieController
  def edit
    authorize @movie
  end

  def destroy
    authorize @movie
    parent_series = @movie.series
    @movie.destroy
    redirect_to series_path(parent_series), notice: 'Episode was successfully deleted.'
  end

  # Index action removed: series index is now the main gallery. Uncomment if you want to keep it for admin or direct access.

  def show
    @movie = policy_scope(Movie).find(params[:id])
    authorize @movie
  end


  def new
    if params[:series_id].blank? || !Series.exists?(params[:series_id])
      redirect_to series_index_path, alert: 'You must select a series before adding an episode.'
      return
    end
    @movie = Movie.new(series_id: params[:series_id])
    authorize @movie
  end


  def create
    if params[:movie][:series_id].blank? || !Series.exists?(params[:movie][:series_id])
      redirect_to series_index_path, alert: 'You must select a series before adding an episode.'
      return
    end
    @movie = Movie.new(movie_params)
    authorize @movie
    tag_ids = params[:movie][:tag_ids] || []
    if @movie.save
      if @movie.series.present?
        # Always sync: movie gets union of its own and series tags, series gets any new movie tags
        movie_tags = Tag.where(id: tag_ids)
        series_tags = @movie.series.tags
        all_tags = (series_tags + movie_tags).uniq
        @movie.tags = all_tags
        new_tags = movie_tags - series_tags
        @movie.series.tags << new_tags unless new_tags.empty?
      else
        @movie.tags = Tag.where(id: tag_ids)
      end
      redirect_to @movie, notice: 'Movie was successfully created.'
    else
      render :new
    end
  end

  def search
    movies = search_movies(params)
    @movies = policy_scope(movies).page(params[:page]).per(12)
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
    @movie = Movie.find(params[:id])
  end 
end
