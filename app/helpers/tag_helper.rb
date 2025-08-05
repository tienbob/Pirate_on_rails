module TagHelper
  def tag_description_preview(tag)
    return "No description available" unless tag.description.present?
    
    # For OpenStruct objects from cache, use a simpler cache key
    cache_key = if tag.respond_to?(:updated_at) && tag.updated_at
      "tag_desc_#{tag.id}_#{tag.updated_at.to_i}"
    else
      "tag_desc_#{tag.id}_#{Time.current.to_i}"
    end
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      truncate(tag.description, length: 100)
    end
  end
  
  def admin_tag_actions(tag)
    return "" unless current_user&.admin?
    
    content_tag(:div, class: 'tag-actions') do
      safe_join([
        link_to('Edit', edit_tag_path(tag), class: 'admin-btn admin-btn-edit'),
        link_to('Delete', tag_path(tag), method: :delete, 
                data: { confirm: 'Are you sure you want to delete this tag?' }, 
                class: 'admin-btn admin-btn-delete')
      ], ' ')
    end
  end
end
