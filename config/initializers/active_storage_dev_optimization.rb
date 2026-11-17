# ActiveStorage development optimizations for large file performance
if Rails.env.development?
  Rails.application.configure do
    # Optimize file serving in development
    config.action_controller.asset_host = nil

    # Reduce ActiveStorage overhead in development
    config.active_storage.draw_routes = true
    config.active_storage.replace_on_assign_to_many = false

    # Disable expensive variant tracking in development
    config.active_storage.track_variants = false

    # Use faster content type detection
    config.active_storage.content_types_to_serve_as_binary = %w[
      text/plain
      text/html
      text/css
      text/javascript
      application/javascript
    ]

    # Optimize blob serving with faster expiration and smaller chunks
    config.active_storage.urls_expire_in = 1.hour  # Longer expiration for dev

    # Enable streaming for large files to prevent memory issues
    config.active_storage.streaming_blob_size_threshold = 2.megabytes  # Lower threshold

    # Use redirect mode to avoid proxy timeout issues
    config.active_storage.resolve_model_to_route = :rails_storage_redirect
  end

  # Wait for Rails to fully initialize before modifying ActiveStorage classes
  Rails.application.config.after_initialize do
    # Optimize ActiveStorage::DiskController for large files
    if defined?(ActiveStorage::DiskController)
      ActiveStorage::DiskController.class_eval do
        # Add caching and streaming headers for better performance
        before_action :set_performance_headers
        before_action :set_streaming_headers, only: [ :show ]

        private

        def set_performance_headers
          # Set appropriate cache headers for development
          response.headers["Cache-Control"] = "public, max-age=300"  # 5 minutes
          response.headers["Vary"] = "Accept"
          response.headers["X-Content-Type-Options"] = "nosniff"
        end

        def set_streaming_headers
          # Enable streaming for large video files
          if @blob&.content_type&.start_with?("video/")
            response.headers["X-Accel-Buffering"] = "no"  # Disable nginx buffering
            response.headers["Accept-Ranges"] = "bytes"    # Enable range requests
          end
        end
      end
    end

    # Enhanced blob error handling
    if defined?(ActiveStorage::Blobs::ProxyController)
      ActiveStorage::Blobs::ProxyController.class_eval do
        # Override set_blob to add better error handling
        def set_blob
          @blob = ActiveStorage::Blob.find_signed!(params[:signed_id])

          # Check if blob file actually exists
          unless @blob.service.exist?(@blob.key)
            Rails.logger.error "ActiveStorage blob #{@blob.id} file missing at key: #{@blob.key}"

            # Schedule cleanup of orphaned blob
            ActiveStorage::PurgeJob.perform_later(@blob)

            # Return 404 immediately instead of timing out
            head :not_found
            nil
          end
        rescue ActiveStorage::InvalidSignature, ActiveRecord::RecordNotFound => e
          Rails.logger.error "Invalid blob signature or not found: #{e.message}"
          head :not_found
        end
      end
    end

    # Skip expensive validations in development
    if defined?(ActiveStorage::Blob)
      ActiveStorage::Blob.class_eval do
        def identify_without_downloading
          # Skip expensive content type identification in development
          if content_type.blank?
            self.content_type = Marcel::MimeType.for(filename.to_s)
          end
        end

        # Optimize metadata extraction for development
        def analyze_without_downloading
          # Skip expensive metadata analysis in development for large files
          if byte_size > 10.megabytes
            Rails.logger.info "Skipping metadata analysis for large file: #{filename}"
            return
          end

          original_analyze
        end

        # Add method to check if file exists
        def file_exists?
          service.exist?(key)
        rescue => e
          Rails.logger.error "Error checking file existence for blob #{id}: #{e.message}"
          false
        end

        # Override identify to use faster method
        alias_method :original_identify, :identify unless method_defined?(:original_identify)
        alias_method :identify, :identify_without_downloading

        # Override analyze to skip large files
        alias_method :original_analyze, :analyze unless method_defined?(:original_analyze)
        alias_method :analyze, :analyze_without_downloading
      end
    end

    # Optimize ActiveStorage attachments
    if defined?(ActiveStorage::Attached::One)
      ActiveStorage::Attached::One.class_eval do
        def url(*args, **options)
          # Add validation for attachment URLs in development
          if attached?
            blob = self.blob
            if blob.file_exists?
              blob.url(*args, **options)
            else
              Rails.logger.warn "File missing for attachment #{name} on #{record.class.name} #{record.id}"
              nil
            end
          else
            nil
          end
        end
      end
    end
  end
end
