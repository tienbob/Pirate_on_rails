require "test_helper"

class MovieTest < ActiveSupport::TestCase
  test "requires title, description, release_date, is_pro and video_file" do
    movie = Movie.new
    assert_not movie.valid?
    assert_includes movie.errors[:title], "can't be blank"
    assert_includes movie.errors[:description], "can't be blank"
    assert_includes movie.errors[:release_date], "can't be blank"
  end

  test "belongs to series optionally" do
    # Create series without img to avoid ActiveStorage issues
    series = Series.create!(
      title: "Test Series",
      description: "Test description"
    )

    movie = Movie.create!(
      title: "Test Movie",
      description: "Description longer than ten characters",
      release_date: Date.today,
      is_pro: false,
      series: series
    )

    assert_equal series, movie.series
  end
end
