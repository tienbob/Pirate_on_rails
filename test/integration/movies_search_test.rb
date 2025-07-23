require "test_helper"


class MoviesSearchTest < ActionDispatch::IntegrationTest
  setup do
    video_path = Rails.root.join("test", "fixtures", "files", "dummy.mp4")
    @user = User.create!(name: "Test User", email: "test@example.com", password: "password123", role: "free")
    @movie1 = Movie.create!(
      title: "The Matrix",
      description: "A computer hacker learns about the true nature of reality.",
      release_date: Date.new(1999, 3, 31),
      is_pro: false,
      video_file: fixture_file_upload(video_path, "video/mp4")
    )
    @movie2 = Movie.create!(
      title: "Inception",
      description: "A thief who steals corporate secrets through dream-sharing technology.",
      release_date: Date.new(2010, 7, 16),
      is_pro: true,
      video_file: fixture_file_upload(video_path, "video/mp4")
    )
    Movie.__elasticsearch__.refresh_index!
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
    follow_redirect! if response.redirect?
  end


  test "should find movie by title via elasticsearch" do
    sign_in_as(@user)
    get search_movies_url, params: { q: "Matrix" }
    assert_response :success
    assert_select "h5.card-title", text: /The Matrix/
  end


  test "should find movie by release year range via elasticsearch" do
    sign_in_as(@user)
    get search_movies_url, params: { year_from: 2010, year_to: 2010 }
    assert_response :success
    assert_select "h5.card-title", text: /Inception/
  end

  test "should return all movies if no search params" do
    sign_in_as(@user)
    get search_movies_url
    assert_response :success
    assert_select "h5.card-title", text: /The Matrix/
    assert_select "h5.card-title", text: /Inception/
  end
end
