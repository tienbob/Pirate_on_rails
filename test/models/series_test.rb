require "test_helper"

class SeriesTest < ActiveSupport::TestCase
  test "valid factory" do
    series = build(:series)
    assert series.valid?
  end

  test "requires title and description" do
    series = Series.new
    assert_not series.valid?
    assert_includes series.errors[:title], "can't be blank"
    assert_includes series.errors[:description], "can't be blank"
  end
end
