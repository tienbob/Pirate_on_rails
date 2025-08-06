module SeriesHelper
  # Efficiently get series image URL with caching and fallback
  def series_image_url(series)
    # Don't cache signed URLs since they expire - only cache the attachment status
    cache_key = "series_#{series.id}_has_image_v1"
    
    has_valid_image = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      if series.img.attached?
        blob = series.img.blob
        # Verify the blob file exists in storage
        blob.service.exist?(blob.key)
      else
        false
      end
    end
    
    if has_valid_image && series.img.attached?
      begin
        # Generate fresh URL every time to avoid expiration issues
        # Use direct routes instead of proxy for better performance
        if Rails.env.development?
          rails_blob_path(series.img, only_path: false)
        else
          rails_blob_url(series.img)
        end
      rescue ActiveStorage::FileNotFoundError => e
        Rails.logger.error "File not found for series #{series.id} image: #{e.message}"
        # Invalidate cache and clean up the broken attachment
        Rails.cache.delete(cache_key)
        series.img.purge_later
        asset_url('series/default.JPG')
      rescue => e
        Rails.logger.error "Error generating image URL for series #{series.id}: #{e.message}"
        asset_url('series/default.JPG')
      end
    elsif series.img.is_a?(String) && series.img.present?
      series.img
    else
      asset_url('series/default.JPG')
    end
  end
end
