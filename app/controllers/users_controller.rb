require "ostruct"

class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [ :index, :destroy ]

  def edit
    @user = User.find_by(id: params[:id])
    unless current_user.admin? || current_user == @user
      redirect_to user_path(current_user), alert: "Access denied."
    end
  end

  def index
    # Cache user statistics with a single query
    @user_stats = Rails.cache.fetch("user_stats_v1", expires_in: 3.minutes) do
      # Use a single query to get all role counts
      role_data = User.group(:role).pluck(:role, Arel.sql("COUNT(*)"))
      total_count = User.count

      stats = {}
      role_data.each do |role, count|
        stats[role] = count
      end

      {
        total: total_count,
        admin_count: stats["admin"] || 0,
        pro_count: stats["pro"] || 0,
        free_count: stats["free"] || 0
      }
    end

    # Extract individual counts for backward compatibility
    @total_users = @user_stats[:total]
    @admin_count = @user_stats[:admin_count]
    @pro_count = @user_stats[:pro_count]
    @free_count = @user_stats[:free_count]

    # Keep the users as ActiveRecord objects for method access
    @users = User.select(:id, :name, :email, :role, :created_at, :last_seen_at)
                 .order(:id)
                 .page(params[:page])
                 .per(5)
  end

  def show
    @user = User.find_by(id: params[:id])
  end


  def new
    @user = User.new
  end


  # Use Devise's registration controller for user creation and confirmation
  # Remove custom create logic

  def update
    @user = User.find_by(id: params[:id])

    if current_user.admin?
      # Handle role separately for admins to avoid mass assignment warnings
      permitted = user_params
      if params[:user][:role].present?
        @user.role = params[:user][:role] if %w[free pro admin].include?(params[:user][:role])
      end
    elsif current_user == @user
      permitted = user_params
    else
      redirect_to user_path(current_user), alert: "Access denied."
      return
    end

    if @user.update(permitted)
      # Clear users cache when user is updated
      Rails.cache.delete("users_total_count")
      Rails.cache.delete("users_admin_count")
      Rails.cache.delete("users_pro_count")
      Rails.cache.delete("users_free_count")
      redirect_to @user, notice: "User was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @user = User.find_by(id: params[:id])
    authorize @user
    if @user.destroy
      # Clear users cache when user is deleted
      Rails.cache.delete("users_total_count")
      Rails.cache.delete("users_admin_count")
      Rails.cache.delete("users_pro_count")
      Rails.cache.delete("users_free_count")
      redirect_to users_path, notice: "User was successfully deleted."
    else
      redirect_to users_path, alert: "Failed to delete user."
    end
  end

  private

  def user_params
    # Only allow safe parameters for mass assignment
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def require_admin
    unless current_user&.admin?
      redirect_to user_path(current_user), alert: "Access denied. Only admins can view the user manager page."
    end
  end
end
