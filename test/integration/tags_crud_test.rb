require "test_helper"

class TagsCrudTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
    @tag = Tag.create!(name: "Test Tag")
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
  end

  test "should get index" do
    sign_in_as(@admin)
    get tags_url
    assert_response :success
  end

  test "should show tag" do
    sign_in_as(@admin)
    get tag_url(@tag)
    assert_response :success
  end

  test "should create tag" do
    sign_in_as(@admin)
    assert_difference('Tag.count') do
      post tags_url, params: { tag: { name: "New Tag" } }
    end
    assert_response :redirect
  end

  test "should update tag" do
    sign_in_as(@admin)
    patch tag_url(@tag), params: { tag: { name: "Updated Tag" } }
    assert_redirected_to tag_url(@tag)
    @tag.reload
    assert_equal "Updated Tag", @tag.name
  end

  test "should destroy tag" do
    sign_in_as(@admin)
    assert_difference('Tag.count', -1) do
      delete tag_url(@tag)
    end
    assert_redirected_to tags_url
  end
end
