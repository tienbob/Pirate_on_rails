# ActiveStorage performance optimizations
Rails.application.configure do
  # Add caching headers for ActiveStorage files
  config.to_prepare do
    ActiveStorage::Blobs::RedirectController.class_eval do
      before_action :set_cache_headers

      private

      def set_cache_headers
        expires_in 1.hour, public: true
        response.headers["Vary"] = "Accept"
      end
    end

    ActiveStorage::DiskController.class_eval do
      before_action :set_cache_headers

      private

      def set_cache_headers
        expires_in 1.hour, public: true
        response.headers["Vary"] = "Accept"
        response.headers["Cache-Control"] = "public, max-age=3600"
        response.headers["X-Accel-Buffering"] = "no"  # Disable nginx buffering for large files
      end
    end
  end
end

# Optimize ActiveStorage URL generation with intelligent caching
# Temporarily disabled URL caching to avoid expiration issues
Rails.application.config.after_initialize do
  # Optimize variant processing for images only
  if defined?(ActiveStorage::Variant)
    ActiveStorage::Variant.class_eval do
      def processed_with_cache
        cache_key = "variant_processed_#{variation.key}_#{blob.checksum}"

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          processed_without_cache
        end
      end

      alias_method :processed_without_cache, :processed
      alias_method :processed, :processed_with_cache
    end
  end
end
