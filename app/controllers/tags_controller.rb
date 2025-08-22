require 'ostruct'

class TagsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_tag, only: [:show, :edit, :update, :destroy]
  
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
    # Optimized query with caching of raw data to avoid serialization issues
    page = params[:page] || 1
    
    # Cache the tag IDs and metadata, not the paginated object
    cached_data = Rails.cache.fetch("tags_data_page_#{page}", expires_in: 5.minutes) do
      # Get total count first (without select to avoid COUNT() issues)
      total_count = Tag.count
      
      # Get the specific page of tags with selected columns
      offset = (page.to_i - 1) * 5
      tags_data = Tag.select(:id, :name, :description, :created_at, :updated_at)
                     .order(:name, :id)
                     .limit(5)
                     .offset(offset)
                     .map do |tag|
        {
          id: tag.id,
          name: tag.name,
          description: tag.description,
          created_at: tag.created_at,
          updated_at: tag.updated_at
        }
      end
      
      { tags: tags_data, total_count: total_count, page: page.to_i, per_page: 5 }
    end
    
    # Recreate the tags as OpenStruct objects for the view
    @tags = Kaminari.paginate_array(
      cached_data[:tags].map { |tag_data| OpenStruct.new(tag_data) },
      total_count: cached_data[:total_count]
    ).page(cached_data[:page]).per(cached_data[:per_page])
  end

  def show
    # @tag is set by before_action :set_tag
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      # Clear cache after creating a new tag
      Rails.cache.delete_matched("tags_data_page_*")
      Rails.cache.delete("all_tags_for_search")  # Clear search form cache
      redirect_to @tag, notice: 'Tag was successfully created.'
    else
      render :new
    end
  end

  def edit
    # @tag is set by before_action :set_tag
  end

  def update
    # @tag is set by before_action :set_tag
    if @tag.update(tag_params)
      # Clear cache after updating a tag
      Rails.cache.delete_matched("tags_data_page_*")
      Rails.cache.delete("all_tags_for_search")  # Clear search form cache
      redirect_to @tag, notice: 'Tag was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    # @tag is set by before_action :set_tag
    @tag.destroy
    # Clear cache after deleting a tag
    Rails.cache.delete_matched("tags_data_page_*")
    Rails.cache.delete("all_tags_for_search")  # Clear search form cache
    redirect_to tags_path, notice: 'Tag was successfully deleted.'
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :description)
  end

  def set_tag
    @tag = Tag.find_by(id: params[:id])
  end
end
