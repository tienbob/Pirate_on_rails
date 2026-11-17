require "test_helper"

class ViewAnalyticTest < ActiveSupport::TestCase
  test "validates viewed_at presence" do
    va = ViewAnalytic.new
    assert_not va.valid?
    assert_includes va.errors[:viewed_at], "can't be blank"
  end

  test "popular_movies returns array" do
    # Use fixtures instead of factories to avoid MessageVerifier issues
    assert_kind_of Array, ViewAnalytic.popular_movies(limit: 5)
  end
end
