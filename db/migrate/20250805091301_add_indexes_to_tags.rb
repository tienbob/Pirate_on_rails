class AddIndexesToTags < ActiveRecord::Migration[8.0]
  def change
    # Critical indexes for tags table performance
    # Primary index on name for searches and ordering
    add_index :tags, :name unless index_exists?(:tags, :name)

    # Composite index for pagination queries (name + id for stable sorting)
    add_index :tags, [ :name, :id ] unless index_exists?(:tags, [ :name, :id ])

    # Timestamps for admin sorting and filtering
    add_index :tags, :created_at unless index_exists?(:tags, :created_at)
    add_index :tags, :updated_at unless index_exists?(:tags, :updated_at)

    # Composite index for most common admin queries
    add_index :tags, [ :updated_at, :id ] unless index_exists?(:tags, [ :updated_at, :id ])
  end
end
