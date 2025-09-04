require "test_helper"

class MovieTagTest < ActiveSupport::TestCase
  test "associations" do
    # Use fixtures instead of factories to avoid MessageVerifier issues
    movie = movies(:movie1)
    tag = Tag.create!(name: "Action")
    mt = MovieTag.create!(movie: movie, tag: tag)
    assert_equal movie, mt.movie
    assert_equal tag, mt.tag
  end
end
