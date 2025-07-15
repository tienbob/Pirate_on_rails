class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [:index]

  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user, notice: 'User was successfully created.'
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :role)
  end

  def require_admin
    unless current_user&.admin?
      redirect_to user_path(current_user), alert: "Access denied. Only admins can view the user manager page."
    end
  end
end
