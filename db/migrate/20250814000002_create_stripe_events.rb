class CreateStripeEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :stripe_events do |t|
      t.string :event_id, null: false
      t.string :event_type
      t.timestamps
    end
    add_index :stripe_events, :event_id, unique: true
  end
end
