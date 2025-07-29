require "test_helper"

class SeriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get series_index_url
    assert_response :success
  end

  test "should get show" do
    get series_show_url
    assert_response :success
  end

  test "should get new" do
    get series_new_url
    assert_response :success
  end

  test "should get create" do
    get series_create_url
    assert_response :success
  end

  test "should get edit" do
    get series_edit_url
    assert_response :success
  end

  test "should get update" do
    get series_update_url
    assert_response :success
  end

  test "should get destroy" do
    get series_destroy_url
    assert_response :success
  end
end
