require "test_helper"

class MoviesCrudTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin User", email: "admin@example.com", password: "password123", role: "admin")
    sign_in_as(@admin)
    @movie = Movie.create!(
      title: "Test Movie",
      description: "A movie for testing.",
      release_date: Date.today,
      is_pro: false,
      video_file: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/dummy.mp4'), 'video/mp4')
    )
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
  end

  test "should get index" do
    sign_in_as(@admin)
    get movies_url
    assert_response :success
  end

  test "should show movie" do
    sign_in_as(@admin)
    get movie_url(@movie)
    assert_response :success
  end

  test "should create movie" do
    sign_in_as(@admin)
    assert_difference('Movie.count') do
      post movies_url, params: { movie: {
        title: "New Movie",
        description: "Another movie.",
        release_date: Date.today,
        is_pro: false,
        video_file: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/dummy.mp4'), 'video/mp4')
      } }
    end
    assert_response :redirect
  end

  test "should update movie" do
    sign_in_as(@admin)
    patch movie_url(@movie), params: { movie: {
      title: "Updated Movie",
      description: "A movie for testing.",
      release_date: Date.today,
      is_pro: false,
      video_file: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/dummy.mp4'), 'video/mp4')
    } }
    assert_redirected_to movie_url(@movie)
    @movie.reload
    assert_equal "Updated Movie", @movie.title
  end

  test "should destroy movie" do
    sign_in_as(@admin)
    assert_difference('Movie.count', -1) do
      delete movie_url(@movie)
    end
    assert_redirected_to movies_url
  end
end
