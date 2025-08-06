module SeriesHelper
  # Efficiently get series image URL with caching and fallback
  def series_image_url(series, variant: :medium)
    # Don't cache signed URLs since they expire - only cache the attachment status
    cache_key = "series_#{series.id}_has_image_v4"
    
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
      # Only use direct ActiveStorage URL, no processing
      if Rails.env.development?
        rails_blob_path(series.img, only_path: false)
      else
        rails_blob_url(series.img)
      end
    elsif series.img.is_a?(String) && series.img.present?
      series.img
    else
      asset_url('series/default.JPG')
    end
  end
end
