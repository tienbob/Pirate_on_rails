module ApplicationCable
  class ChatChannel < Channel
    def subscribed
      stream_for current_user
    end
  end
end
