module MovieHelper
  # Get optimized video URL for streaming
  def movie_video_url(movie)
    if movie.video_file.attached?
      # Use direct streaming route for maximum performance
      direct_video_stream_path(movie_id: movie.id)
    else
      nil
    end
  end
  
  # Get video file size for display
  def movie_video_size(movie)
    if movie.video_file.attached?
      number_to_human_size(movie.video_file.blob.byte_size)
    else
      'Unknown'
    end
  end
end
