class VideoStreamController < ApplicationController
  # Skip unnecessary middleware for better streaming performance
  skip_before_action :verify_authenticity_token
  
  before_action :authenticate_user!
  before_action :set_movie_cached
  before_action :authorize_movie
  
  def show
    blob = @movie.video_file.blob
    
    # Check if blob exists and file is accessible
    unless blob&.service&.exist?(blob.key)
      render json: { error: 'Video file not found' }, status: :not_found
      return
    end
    
    # Handle range requests for video streaming
    if request.headers['Range'].present?
      stream_video_with_range(blob)
    else
      stream_video_full(blob)
    end
  end
  
  private
  
  def set_movie_cached
    # Use caching to avoid repeated database queries
    cache_key = "movie_video_#{params[:movie_id]}_#{current_user.id}"
    @movie = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      Movie.includes(video_file_attachment: :blob).find(params[:movie_id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Movie not found' }, status: :not_found
  end
  
  def authorize_movie
    authorize @movie
  rescue Pundit::NotAuthorizedError
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
  
  def stream_video_with_range(blob)
    file_path = get_file_path(blob)
    file_size = get_file_size(blob, file_path)
    
    # Parse range header more efficiently
    range_start, range_end = parse_range_header(request.headers['Range'], file_size)
    content_length = range_end - range_start + 1
    
    # Set response headers efficiently
    set_streaming_headers(blob, range_start, range_end, file_size, content_length)
    
    # Stream file with optimized chunk size
    stream_file_range(file_path, range_start, content_length)
  end
  
  def stream_video_full(blob)
    file_path = get_file_path(blob)
    file_size = get_file_size(blob, file_path)
    
    # Set response headers for full file
    response.headers.merge!({
      'Content-Type' => blob.content_type,
      'Content-Length' => file_size.to_s,
      'Accept-Ranges' => 'bytes',
      'Cache-Control' => 'private, max-age=3600',
      'X-Accel-Buffering' => 'no' # Disable nginx buffering
    })
    
    # Stream entire file efficiently
    stream_file_range(file_path, 0, file_size)
  end
  
  def get_file_path(blob)
    # Cache file path lookup
    Rails.cache.fetch("blob_path_#{blob.key}", expires_in: 1.hour) do
      blob.service.path_for(blob.key)
    end
  end
  
  def get_file_size(blob, file_path)
    # Use blob byte_size if available (cached), otherwise check file
    blob.byte_size || File.size(file_path)
  end
  
  def parse_range_header(range_header, file_size)
    # Optimized range parsing
    range_match = range_header.match(/bytes=(\d+)-(\d*)/)
    start_byte = range_match[1].to_i
    end_byte = range_match[2].present? ? range_match[2].to_i : file_size - 1
    
    # Ensure valid range
    end_byte = [end_byte, file_size - 1].min
    start_byte = [start_byte, 0].max
    
    [start_byte, end_byte]
  end
  
  def set_streaming_headers(blob, start_byte, end_byte, file_size, content_length)
    response.status = 206 # Partial Content
    response.headers.merge!({
      'Content-Range' => "bytes #{start_byte}-#{end_byte}/#{file_size}",
      'Accept-Ranges' => 'bytes',
      'Content-Length' => content_length.to_s,
      'Content-Type' => blob.content_type,
      'Cache-Control' => 'private, max-age=3600',
      'X-Accel-Buffering' => 'no' # Disable nginx buffering
    })
  end
  
  def stream_file_range(file_path, start_position, total_bytes)
    # Optimized streaming with larger chunks and error handling
    chunk_size = 64.kilobytes # Increased chunk size for better performance
    
    File.open(file_path, 'rb') do |file|
      file.seek(start_position)
      remaining = total_bytes
      
      while remaining > 0 && !response.stream.closed?
        bytes_to_read = [remaining, chunk_size].min
        chunk = file.read(bytes_to_read)
        
        break if chunk.nil? || chunk.empty?
        
        response.stream.write(chunk)
        remaining -= chunk.bytesize
        
        # Allow other requests to be processed
        Thread.pass if remaining > 0
      end
    end
  rescue Errno::EPIPE, IOError => e
    # Client disconnected - this is normal for video streaming
    Rails.logger.debug "Video streaming interrupted: #{e.message}"
  rescue => e
    Rails.logger.error "Video streaming error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  ensure
    response.stream.close unless response.stream.closed?
  end
end
