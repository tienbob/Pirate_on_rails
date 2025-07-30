class RemoveImgFromSeries < ActiveRecord::Migration[7.0]
  def change
    remove_column :series, :img, :string
  end
end
