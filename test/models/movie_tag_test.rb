require "test_helper"

class MovieTagTest < ActiveSupport::TestCase
  test "associations" do
    movie = create(:movie)
    tag = create(:tag)
    mt = create(:movie_tag, movie: movie, tag: tag)
    assert_equal movie, mt.movie
    assert_equal tag, mt.tag
  end
end
