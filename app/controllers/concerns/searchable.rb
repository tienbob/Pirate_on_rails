module Searchable
  extend ActiveSupport::Concern

  included do
    # nothing needed here for now
  end

  # This function is no longer used, but kept for reference.
  # It demonstrates how to search movies using Elasticsearch and cache the results.
  # - Builds a cache key based on search params and user.
  # - Constructs search conditions for title, year range, and tags.
  # - Uses Elasticsearch to search Movie records, then fetches matching AR records.
  # - Returns all movies if no search conditions are present.
  def search_movies(params)
    cache_key = [
      "search",
      params[:q],
      params[:year_from],
      params[:year_to],
      params[:tags]&.sort,
      (respond_to?(:current_user) ? current_user&.id : nil)
    ].join(":")
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      query = params[:q]
      year_from = params[:year_from]
      year_to = params[:year_to]
      tags = params[:tags]
      search_conditions = []
      # Add title match if present
      if query.present?
        search_conditions << { match: { title: query } }
      end
      # Add year range if present
      if year_from.present? || year_to.present?
        range = {}
        range[:gte] = "#{year_from}-01-01" if year_from.present?
        range[:lte] = "#{year_to}-12-31" if year_to.present?
        search_conditions << { range: { release_date: range } }
      end
      # Add tag matches if present
      if tags.present?
        tags.each do |tag|
          search_conditions << { nested: {
            path: 'tags',
            query: { match: { 'tags.name': tag } }
          }}
        end
      end
      # If any search conditions, use Elasticsearch; else return all movies
      if search_conditions.any?
        movies = Movie.__elasticsearch__.search({
          query: {
            bool: {
              must: search_conditions
            }
          }
        }).records
        ar_movies = Movie.includes(:tags, :series).where(id: movies.map(&:id))
        ar_movies
      else
        Movie.includes(:tags, :series).all
      end
    end
  end

  # Main search for series, used in the app.
  # - Builds a cache key from search params and user.
  # - Constructs search conditions for title and tags.
  # - Uses Elasticsearch to search Series records, then fetches matching AR records.
  # - Returns all series if no search conditions are present.
  # - Handles errors gracefully: if search fails, shows a flash alert and redirects back.
  def search_series(params)
    cache_key = [
      "search_series_v2",
      params[:q],
      params[:tags]&.sort,
      (respond_to?(:current_user) ? current_user&.id : nil)
    ].join(":")
    begin
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        query = params[:q]
        tags = params[:tags]
        # Fix for tags submitted as a single comma-separated string
        if tags.is_a?(Array) && tags.size == 1 && tags.first.include?(',')
          tags = tags.first.split(',').map(&:strip)
        end
        search_conditions = []
        # Add title match if present
        if query.present?
          search_conditions << { match: { title: query } }
        end
        # Add tag matches if present
        if tags.present?
          tags.each do |tag|
            search_conditions << { nested: {
              path: 'tags',
              query: { match: { 'tags.name': tag } }
            }}
          end
        end
        # If any search conditions, use Elasticsearch; else return all series
        if search_conditions.any?
          Rails.logger.info "ElasticSearch: Searching series with conditions: #{search_conditions.inspect}"
          
          # Use Elasticsearch search with size limit to avoid loading everything
          search_results = Series.__elasticsearch__.search({
            query: {
              bool: {
                must: search_conditions
              }
            },
            size: 1000  # Reasonable limit to prevent memory issues
          })
          
          series_ids = search_results.records.map(&:id)
          ar_series = Series.includes(:tags, movies: :tags).where(id: series_ids)
          Rails.logger.info "ElasticSearch: Found #{ar_series.count} series matching conditions."
          ar_series
        else
          Series.includes(:tags, movies: :tags).all
          Rails.logger.info "ElasticSearch: No search conditions provided, returning all series."
        end
      end
    rescue => e
      # Log error details for debugging
      Rails.logger.error "Elasticsearch search_series error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      
      # Fallback to database search instead of crashing
      Rails.logger.info "Falling back to database search"
      fallback_search_series(params)
    end
  end

  private

  # Fallback search using database queries when Elasticsearch is unavailable
  def fallback_search_series(params)
    query = params[:q]
    tags = params[:tags]
    
    # Fix for tags submitted as a single comma-separated string
    if tags.is_a?(Array) && tags.size == 1 && tags.first.include?(',')
      tags = tags.first.split(',').map(&:strip)
    end
    
    series_scope = Series.includes(:tags, movies: :tags)
    
    # Add title search if present
    if query.present?
      series_scope = series_scope.where("title ILIKE ?", "%#{query}%")
    end
    
    # Add tag search if present
    if tags.present?
      series_scope = series_scope.joins(:tags).where(tags: { name: tags })
    end
    
    series_scope
  end
end
