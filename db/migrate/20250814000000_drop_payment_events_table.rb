class DropPaymentEventsTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :payment_events do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :event_type
      t.jsonb :event_data
      t.timestamps
    end
  end
end
