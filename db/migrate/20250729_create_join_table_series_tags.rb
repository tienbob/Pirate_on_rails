class CreateJoinTableSeriesTags < ActiveRecord::Migration[7.0]
  def change
    create_join_table :series, :tags do |t|
      t.index [ :series_id, :tag_id ]
      t.index [ :tag_id, :series_id ]
    end
  end
end
