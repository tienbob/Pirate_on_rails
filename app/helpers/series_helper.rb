module SeriesHelper
  # Efficiently get series image URL with caching and fallback
  def series_image_url(series, variant: :medium)
    # Don't cache signed URLs since they expire - only cache the attachment status
    cache_key = "series_#{series.id}_has_image_v5"
    
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
        # Generate optimized variant with fallback support
        variant_img = case variant
        when :thumb
          # Try WebP first, fallback to JPEG if ImageMagick doesn't support WebP
          create_variant_with_fallback(series.img, resize_to_limit: [160, 90], quality: 85)
        when :medium
          create_variant_with_fallback(series.img, resize_to_limit: [320, 180], quality: 80)
        when :large
          create_variant_with_fallback(series.img, resize_to_limit: [640, 360], quality: 85)
        else
          # For original size, still optimize quality
          create_variant_with_fallback(series.img, quality: 85)
        end
        
        # Generate fresh URL every time to avoid expiration issues
        # Use direct routes instead of proxy for better performance
        if Rails.env.development?
          rails_blob_path(variant_img, only_path: false)
        else
          rails_blob_url(variant_img)
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

  private

  # Create image variant with WebP fallback to JPEG
  def create_variant_with_fallback(attachment, **options)
    # Check if WebP is supported by ImageMagick
    webp_supported = Rails.cache.fetch("imagemagick_webp_support", expires_in: 1.hour) do
      check_webp_support
    end

    if webp_supported
      # Try WebP format first
      begin
        return attachment.variant(**options, format: :webp)
      rescue => e
        Rails.logger.warn "WebP variant failed for attachment #{attachment.id}: #{e.message}"
        # Fallback to JPEG
      end
    end

    # Fallback to JPEG format (more compatible)
    begin
      attachment.variant(**options, format: :jpeg)
    rescue => e
      Rails.logger.error "JPEG variant failed for attachment #{attachment.id}: #{e.message}"
      # Return original attachment if all variants fail
      attachment
    end
  end

  # Check if ImageMagick supports WebP format
  def check_webp_support
    return false unless defined?(MiniMagick)
    
    begin
      # Test WebP support by trying to create a small WebP image
      MiniMagick::Tool::Convert.new do |convert|
        convert << "xc:white[1x1]"
        convert << "webp:-"
      end
      true
    rescue => e
      Rails.logger.info "WebP not supported by ImageMagick: #{e.message}"
      false
    end
  rescue
    false
  end
end
