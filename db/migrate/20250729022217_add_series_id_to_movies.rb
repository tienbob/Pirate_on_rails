class AddSeriesIdToMovies < ActiveRecord::Migration[8.0]
  def up
    add_reference :movies, :series, null: true, foreign_key: true

    # Backfill: create a default series if needed and assign to movies without a series
    # Use insert_all! to avoid running model validations/callbacks (these can invoke
    # signed verifiers or external services and break during migrations).
    now = Time.current
    unless Series.where(title: 'Uncategorized').exists?
      Series.insert_all!([
        { title: 'Uncategorized', description: 'Default series for orphaned movies', created_at: now, updated_at: now }
      ])
    end

    default_series_id = Series.where(title: 'Uncategorized').pluck(:id).first
    Movie.where(series_id: nil).update_all(series_id: default_series_id) if default_series_id

    change_column_null :movies, :series_id, false
  end

  def down
    remove_reference :movies, :series, foreign_key: true
    Series.where(title: 'Uncategorized').destroy_all
  end
end
