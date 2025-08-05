module SeriesHelper
  # Efficiently get series image URL with caching and fallback
  def series_image_url(series)
    cache_key = "series_#{series.id}_image_url_v8"
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      if series.img.attached?
        begin
          # Use standard Rails blob URL without custom expiration
          rails_blob_url(series.img)
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
end
