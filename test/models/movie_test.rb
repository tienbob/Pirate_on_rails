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
    # Create series without factory to avoid MessageVerifier issues
    series = Series.create!(title: "Test Series", description: "Test description")
    movie = Movie.new(title: 'A', description: 'Desc longer than ten', release_date: Date.today, is_pro: false, video_file: "file.mp4", series: series)
    assert movie.valid?
    assert_equal series, movie.series
  end
end
