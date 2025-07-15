class MoviesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_movie, only: [:show, :edit, :update, :destroy]
  after_action :verify_authorized, except: [:index, :show]

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
    @movies = Movie.all
  end

  def show
    @movie = Movie.find(params[:id])
    authorize @movie
  end

  def new
    @movie = Movie.new
  end

  def create
    @movie = Movie.new(movie_params)
    if @movie.save
      redirect_to @movie, notice: 'Movie was successfully created.'
    else
      render :new
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
