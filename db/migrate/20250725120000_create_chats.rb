class CreateChats < ActiveRecord::Migration[7.0]
  def change
    create_table :chats do |t|
      t.text :user_message, null: false
      t.text :ai_response
      t.references :user, foreign_key: true, null: true
      t.timestamps
    end
  end
end
