class MoviesController < ApplicationController
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
    @movies = policy_scope(Movie).page(params[:page]).per(12)
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
    query = params[:q]
    year_from = params[:year_from]
    year_to = params[:year_to]
    tags = params[:tags]
    search_conditions = []
    if query.present?
      search_conditions << { match: { title: query } }
    end
    if year_from.present? || year_to.present?
      range = {}
      if year_from.present?
        range[:gte] = "#{year_from}-01-01"
      end
      if year_to.present?
        range[:lte] = "#{year_to}-12-31"
      end
      search_conditions << { range: { release_date: range } }
    end
    if tags.present?
      tags.each do |tag|
        search_conditions << { nested: {
          path: 'tags',
          query: { match: { 'tags.name': tag } }
        }}
      end
    end
    if search_conditions.any?
      # Elasticsearch returns an array, convert to AR relation for policy_scope
      movies = Movie.__elasticsearch__.search({
        query: {
          bool: {
            must: search_conditions
          }
        }
      }).records
      ar_movies = Movie.where(id: movies.map(&:id))
      @movies = policy_scope(ar_movies).page(params[:page]).per(12)
    else
      @movies = policy_scope(Movie).page(params[:page]).per(12)
    end
    render :index
  end

  private

  def movie_params
    params.require(:movie).permit(:title, :description, :release_date, :is_pro, :video_file)
  end

  def set_movie
    @movie = Movie.find(params[:id])
  end 
end
