class AddDescriptionToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :description, :string
  end
end
