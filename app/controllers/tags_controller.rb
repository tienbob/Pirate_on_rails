class TagsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  # Only allow admins to perform certain actions
  def require_admin
    unless current_user && current_user.admin?
      if user_signed_in?
        redirect_to authenticated_root_path, alert: 'Access denied. Only admins can manage tags.'
      else
        redirect_to unauthenticated_root_path, alert: 'Access denied. Only admins can manage tags.'
      end
    end
  end

  def index
    # Kaminari pagination: params[:page] is used by default
    @tags = Tag.page(params[:page]).per(5)
  end

  def show
    @tag = Tag.find(params[:id])
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to @tag, notice: 'Tag was successfully created.'
    else
      render :new
    end
  end

  def edit
    @tag = Tag.find(params[:id])
  end

  def update
    @tag = Tag.find(params[:id])
    if @tag.update(tag_params)
      redirect_to @tag, notice: 'Tag was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @tag = Tag.find(params[:id])
    @tag.destroy
    redirect_to tags_path, notice: 'Tag was successfully deleted.'
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :description)
  end

  def set_tag
    @tag = Tag.find(params[:id])
  end
end
