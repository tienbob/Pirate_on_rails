class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount
      t.string :currency
      t.string :status
      t.string :stripe_charge_id
      t.text :error_message

      t.timestamps
    end
  end
end
