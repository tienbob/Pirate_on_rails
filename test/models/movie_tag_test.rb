require "test_helper"

class MovieTagTest < ActiveSupport::TestCase
  test "associations" do
    # Create a series first since series_id is required in the database
    series = Series.create!(
      title: "Test Series",
      description: "Test series description"
    )

    # Create movie with required series
    movie = Movie.create!(
      title: "Test Movie",
      description: "Test description longer than ten chars",
      release_date: Date.today,
      is_pro: false,
      series: series
    )

    tag = Tag.create!(name: "Test Tag")

    movie_tag = MovieTag.create!(movie: movie, tag: tag)

    assert_not_nil movie_tag.movie
    assert_not_nil movie_tag.tag
    assert_equal movie, movie_tag.movie
    assert_equal tag, movie_tag.tag
  end
end
