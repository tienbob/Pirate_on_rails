class AddConfirmableToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    # Optionally, add an index for confirmation_token for faster lookups
    add_index :users, :confirmation_token, unique: true
  end
end