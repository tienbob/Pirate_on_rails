require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "validates presence of user_message" do
    chat = Chat.new(ai_response: '')
    assert_not chat.valid?
    assert_includes chat.errors[:user_message], "can't be blank"
  end

  test "can belong to user" do
    user = create(:user)
    chat = create(:chat, user: user)
    assert_equal user, chat.user
  end
end
