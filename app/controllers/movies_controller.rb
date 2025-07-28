class MoviesController < ApplicationController
  include Searchable
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_movie, only: [:show, :edit, :update, :destroy]
  after_action :verify_authorized, except: [:index, :show, :search]
  after_action :verify_policy_scoped, only: [:index, :search]
  # Only allow admins to perform certain actions
  def require_admin
    unless current_user && current_user.admin?
      redirect_to movies_path, alert: 'You are not authorized to perform this action.'
    end
  end

  # Ensure that the user is authorized for actions
  def authorize_user
    authorize @movie
  end
  
  # Actions for the MovieController
  def edit
    authorize_user
  end

  def update
    authorize_user
    if @movie.update(movie_params)
      redirect_to @movie, notice: 'Movie was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize_user
    @movie.destroy
    redirect_to movies_path, notice: 'Movie was successfully deleted.'
  end

  # Other actions remain unchanged
  def index
    # Kaminari pagination: params[:page] is used by default
    page = (params[:page] || 1).to_i
    per_page = 8
    movies_scope = policy_scope(Movie).includes(:tags)
    if page <= 3
      cached_ids = Rails.cache.fetch(["movies_index_ids", page, current_user&.id], expires_in: 10.minutes) do
        movies_scope.page(page).per(per_page).pluck(:id)
      end
      @movies = movies_scope.where(id: cached_ids).order(:id)
      @movies = Kaminari.paginate_array(@movies, total_count: movies_scope.count).page(page).per(per_page)
    else
      @movies = movies_scope.page(page).per(per_page)
    end
  end

  def show
    @movie = policy_scope(Movie).find(params[:id])
    authorize @movie
  end

  def new
    @movie = Movie.new
    authorize @movie
  end

  def create
    @movie = Movie.new(movie_params)
    authorize @movie
    if @movie.save
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
    params.require(:movie).permit(:title, :description, :release_date, :is_pro, :video_file)
  end

  def set_movie
    @movie = Movie.find(params[:id])
  end 
end
