class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [:index, :destroy]
  def edit
    @user = User.find(params[:id])
    unless current_user.admin? || current_user == @user
      redirect_to user_path(current_user), alert: "Access denied."
    end
  end

  def index
    @users = User.page(params[:page]).per(5)
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
      UserMailerJob.perform_later(@user.id)
      redirect_to @user, notice: 'User was successfully created.'
    else
      render :new
    end
  end
  
  def update
    @user = User.find(params[:id])
    if current_user.admin?
      permitted = user_params
    elsif current_user == @user
      permitted = params.require(:user).permit(:email, :password, :password_confirmation)
    else
      redirect_to user_path(current_user), alert: "Access denied."
      return
    end
    if @user.update(permitted)
      redirect_to @user, notice: 'User was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @user = User.find(params[:id])
    authorize @user
    if @user.destroy    
      redirect_to users_path, notice: 'User was successfully deleted.'
    else
      redirect_to users_path, alert: 'Failed to delete user.'
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  def require_admin
    unless current_user&.admin?
      redirect_to user_path(current_user), alert: "Access denied. Only admins can view the user manager page."
    end
  end
end
