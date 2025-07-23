require "test_helper"

class UsersCrudTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Test User", email: "test@example.com", password: "password123", role: "free")
    @admin = User.create!(name: "Admin User", email: "admin@example.com", password: "password123", role: "admin")
  end

  # Helper for sign in
  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
  end

  test "should get index" do
    sign_in_as(@admin)
    get users_url
    assert_response :success
  end

  test "should show user" do
    sign_in_as(@user)
    get user_url(@user)
    assert_response :success
  end

  test "should create user" do
    assert_difference('User.count') do
      post users_url, params: { user: { name: "New User", email: "new@example.com", password: "password123", password_confirmation: "password123", role: "free" } }
    end
    if response.status == 200 && defined?(assigns) && assigns(:user)
      puts "Create failed: ", assigns(:user).errors.full_messages
    end
    assert_response :redirect
  end

  test "should update user" do
    sign_in_as(@user)
    patch user_url(@user), params: { user: { email: "updated@example.com", name: "Updated User", role: "free", password: "password123", password_confirmation: "password123" } }
    if response.status == 200 && defined?(assigns) && assigns(:user)
      puts "Update failed: ", assigns(:user).errors.full_messages
    end
    assert_redirected_to user_url(@user)
    @user.reload
    assert_equal "updated@example.com", @user.email
    assert_equal "Updated User", @user.name
  end

  test "should destroy user" do
    sign_in_as(@user)
    assert_difference('User.count', -1) do
      delete user_url(@user)
    end
    assert_redirected_to users_url
  end

  
end
