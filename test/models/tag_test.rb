require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "validates name presence and uniqueness" do
    create(:tag, name: 'Drama')
    t = build(:tag, name: 'Drama')
    assert_not t.valid?
  end
end
