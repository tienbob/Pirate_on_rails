class AddSeriesIdToMovies < ActiveRecord::Migration[8.0]
  def up
    add_reference :movies, :series, null: true, foreign_key: true

    # Backfill: create a default series if needed and assign to movies without a series
    default_series = Series.create!(title: 'Uncategorized', description: 'Default series for orphaned movies', img: 'default.png')
    Movie.where(series_id: nil).update_all(series_id: default_series.id)

    change_column_null :movies, :series_id, false
  end

  def down
    remove_reference :movies, :series, foreign_key: true
    Series.where(title: 'Uncategorized').destroy_all
  end
end
