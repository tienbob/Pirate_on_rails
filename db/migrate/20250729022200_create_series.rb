class CreateSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :series do |t|
      t.string :title
      t.text :description
      t.string :img

      t.timestamps
    end
  end
end
