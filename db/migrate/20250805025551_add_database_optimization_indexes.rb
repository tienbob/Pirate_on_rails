class AddDatabaseOptimizationIndexes < ActiveRecord::Migration[8.0]
  def change
    # Index for series queries
    add_index :series, :updated_at unless index_exists?(:series, :updated_at)
    add_index :series, [ :updated_at, :id ] unless index_exists?(:series, [ :updated_at, :id ])

    # Index for movies queries
    add_index :movies, :series_id unless index_exists?(:movies, :series_id)
    add_index :movies, [ :series_id, :release_date ] unless index_exists?(:movies, [ :series_id, :release_date ])
    add_index :movies, :release_date unless index_exists?(:movies, :release_date)

    # Index for series_tags (HABTM)
    add_index :series_tags, :series_id unless index_exists?(:series_tags, :series_id)
    add_index :series_tags, :tag_id unless index_exists?(:series_tags, :tag_id)
    add_index :series_tags, [ :series_id, :tag_id ], unique: true unless index_exists?(:series_tags, [ :series_id, :tag_id ])

    # Index for movie_tags
    add_index :movie_tags, :movie_id unless index_exists?(:movie_tags, :movie_id)
    add_index :movie_tags, :tag_id unless index_exists?(:movie_tags, :tag_id)
    add_index :movie_tags, [ :movie_id, :tag_id ], unique: true unless index_exists?(:movie_tags, [ :movie_id, :tag_id ])

    # Index for user activity tracking
    add_index :users, :last_seen_at unless index_exists?(:users, :last_seen_at)
    add_index :users, :updated_at unless index_exists?(:users, :updated_at)

    # Index for payments
    add_index :payments, [ :user_id, :status ] unless index_exists?(:payments, [ :user_id, :status ])
    add_index :payments, [ :user_id, :created_at ] unless index_exists?(:payments, [ :user_id, :created_at ])
  end
end
