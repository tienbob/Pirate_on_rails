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
      "search_series",
      params[:q],
      params[:tags]&.sort,
      (respond_to?(:current_user) ? current_user&.id : nil)
    ].join(":")
    begin
      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        query = params[:q]
        tags = params[:tags]
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
          series = Series.__elasticsearch__.search({
            query: {
              bool: {
                must: search_conditions
              }
            }
          }).records
          ar_series = Series.includes(:tags, movies: :tags).where(id: series.map(&:id))
          ar_series
        else
          Series.includes(:tags, movies: :tags).all
        end
      end
    rescue => e
      # If in a controller context, show a flash alert and redirect back
      if defined?(redirect_back)
        flash[:alert] = "Search is not available, please try again later."
        redirect_back(fallback_location: series_index_path)
        return Series.none
      else
        raise e
      end
    end
  end
end
