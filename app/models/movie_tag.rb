class MovieTag < ApplicationRecord
  belongs_to :movie
  belongs_to :tag
end
