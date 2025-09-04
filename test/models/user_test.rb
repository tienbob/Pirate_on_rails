require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "default role is free" do
    u = build(:user)
    assert_equal 'free', u.role
  end

  test "role helpers" do
    u = build(:user)
    u.role = 'admin'
    assert u.admin?
    u.role = 'pro'
    assert u.pro?
  end
end
