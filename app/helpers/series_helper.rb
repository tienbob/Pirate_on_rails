module SeriesHelper
  # Generate truly static image URL that doesn't change on each request
  def series_static_image_url(series)
    return asset_url("series/default.JPG") unless series.img.attached?

    blob = series.img.blob
    # Generate permanent disk storage URL without expiration
    encoded_key = ActiveStorage.verifier.generate(blob.key, expires_in: nil)
    "/rails/active_storage/disk/#{encoded_key}/#{blob.filename}"
  end

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
      asset_url("series/default.JPG")
    end
  end

  # Generate a static image URL that doesn't expire
  def series_static_image_url(series)
    if series.img.attached?
      # Use rails_blob_path but with a very long expiration to minimize regeneration
      blob = series.img.blob
      # Generate URL with 10 year expiration to make it essentially permanent
      rails_blob_path(blob, expires_in: 10.years, disposition: "inline")
    else
      ActionController::Base.helpers.asset_url("series/default.JPG")
    end
  end
end
