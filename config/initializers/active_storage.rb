# ActiveStorage performance optimizations
Rails.application.configure do
  # Add caching headers for ActiveStorage files
  config.to_prepare do
    ActiveStorage::Blobs::RedirectController.class_eval do
      before_action :set_cache_headers
      
      private
      
      def set_cache_headers
        expires_in 1.hour, public: true
        response.headers['Vary'] = 'Accept'
      end
    end
    
    ActiveStorage::DiskController.class_eval do
      before_action :set_cache_headers
      
      private
      
      def set_cache_headers
        expires_in 1.hour, public: true
        response.headers['Vary'] = 'Accept'
        response.headers['Cache-Control'] = 'public, max-age=3600'
      end
    end
  end
end

# Optimize ActiveStorage URL generation
Rails.application.config.after_initialize do
  # Cache ActiveStorage blob URLs for better performance
  ActiveStorage::Blob.class_eval do
    def url_with_cache(expires_in: ActiveStorage.service_urls_expire_in, disposition: :inline, filename: nil, **options)
      cache_key = "blob_url_#{key}_#{disposition}_#{filename}_#{expires_in}"
      
      Rails.cache.fetch(cache_key, expires_in: [expires_in / 2, 10.minutes].min) do
        url_without_cache(expires_in: expires_in, disposition: disposition, filename: filename, **options)
      end
    end
    
    alias_method :url_without_cache, :url
    alias_method :url, :url_with_cache
  end
end
