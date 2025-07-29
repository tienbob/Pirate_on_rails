module Searchable
  extend ActiveSupport::Concern

  included do
    # nothing needed here for now
  end

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
      if query.present?
        search_conditions << { match: { title: query } }
      end
      if year_from.present? || year_to.present?
        range = {}
        range[:gte] = "#{year_from}-01-01" if year_from.present?
        range[:lte] = "#{year_to}-12-31" if year_to.present?
        search_conditions << { range: { release_date: range } }
      end
      if tags.present?
        tags.each do |tag|
          search_conditions << { nested: {
            path: 'tags',
            query: { match: { 'tags.name': tag } }
          }}
        end

  def search_series(params)
    cache_key = [
      "search_series",
      params[:q],
      params[:tags]&.sort,
      (respond_to?(:current_user) ? current_user&.id : nil)
    ].join(":")
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      query = params[:q]
      tags = params[:tags]
      search_conditions = []
      if query.present?
        search_conditions << { match: { title: query } }
      end
      if tags.present?
        tags.each do |tag|
          search_conditions << { nested: {
            path: 'tags',
            query: { match: { 'tags.name': tag } }
          }}
        end
      end
      if search_conditions.any?
        series = Series.__elasticsearch__.search({
          query: {
            bool: {
              must: search_conditions
            }
          }
        }).records
        ar_series = Series.where(id: series.map(&:id))
        ar_series
      else
        Series.all
      end
    end
  end
      end
      if search_conditions.any?
        movies = Movie.__elasticsearch__.search({
          query: {
            bool: {
              must: search_conditions
            }
          }
        }).records
        ar_movies = Movie.where(id: movies.map(&:id))
        ar_movies
      else
        Movie.all
      end
    end
  end
end
