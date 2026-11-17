class AddPerformanceAndSecurityImprovements < ActiveRecord::Migration[8.0]
  def up
    # Add indexes for better query performance
    add_index :movies, [ :is_pro, :release_date ], name: 'index_movies_on_pro_and_release_date'
    add_index :movies, [ :series_id, :created_at ], name: 'index_movies_on_series_and_created_at'
    add_index :payments, [ :user_id, :status ], name: 'index_payments_on_user_and_status'
    add_index :payments, [ :status, :created_at ], name: 'index_payments_on_status_and_created_at'
    add_index :payments, :stripe_charge_id, unique: true, name: 'index_payments_on_stripe_charge_id'

    # Add user activity tracking
    add_column :users, :last_seen_at, :datetime
    add_column :users, :login_count, :integer, default: 0
    add_index :users, :last_seen_at

    # Add view analytics table
    create_table :view_analytics do |t|
      t.references :user, null: false, foreign_key: true
      t.references :movie, null: false, foreign_key: true
      t.datetime :viewed_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.integer :watch_duration # in seconds
      t.boolean :completed_viewing, default: false

      t.timestamps
    end

    add_index :view_analytics, [ :movie_id, :viewed_at ]
    add_index :view_analytics, [ :user_id, :viewed_at ]

    # Add payment audit trail
    create_table :payment_events do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :event_type, null: false # created, updated, completed, failed, etc.
      t.text :event_data # JSON data
      t.string :source # webhook, manual, system
      t.timestamps
    end

    add_index :payment_events, [ :payment_id, :created_at ]
    add_index :payment_events, :event_type

    # Fix currency column - first update NULL values, then add constraint
    execute "UPDATE payments SET currency = 'usd' WHERE currency IS NULL"
    change_column_null :payments, :currency, false
    change_column_default :payments, :currency, 'usd'
    add_column :payments, :processed_at, :datetime
    add_column :payments, :metadata, :text # JSON field for additional data
  end

  def down
    # Remove indexes
    remove_index :movies, name: 'index_movies_on_pro_and_release_date'
    remove_index :movies, name: 'index_movies_on_series_and_created_at'
    remove_index :payments, name: 'index_payments_on_user_and_status'
    remove_index :payments, name: 'index_payments_on_status_and_created_at'
    remove_index :payments, name: 'index_payments_on_stripe_charge_id'

    # Remove user activity tracking
    remove_index :users, :last_seen_at
    remove_column :users, :login_count
    remove_column :users, :last_seen_at

    # Remove analytics tables
    drop_table :payment_events
    drop_table :view_analytics

    # Revert payment changes
    remove_column :payments, :metadata
    remove_column :payments, :processed_at
    change_column_null :payments, :currency, true
    change_column_default :payments, :currency, nil
  end
end
