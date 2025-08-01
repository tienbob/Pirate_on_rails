class ChatsController < ApplicationController
  include Searchable
  before_action :authenticate_user!
  protect_from_forgery with: :null_session

  # 1. User chat message comes in
  def create
    user_message = params[:message]
    response = Faraday.post("http://localhost:5000/chat", { message: user_message }.to_json, "Content-Type" => "application/json")
    ai_response = JSON.parse(response.body)["response"] rescue "Sorry, AI service unavailable."
    chat = Chat.create!(user_message: user_message, ai_response: ai_response, user: current_user)
    # Broadcast to Action Cable
    ChatChannel.broadcast_to(current_user, {
      user_message: chat.user_message,
      ai_response: chat.ai_response,
      created_at: chat.created_at
    })
    render json: { response: ai_response }
  end

  # 2. Python agent can call this endpoint to fetch all series data for semantic search
  def series_data
    series = Series.includes(:movies, :tags).all
    result = series.map do |s|
      {
        title: s.title,
        description: s.description,
        img: s.img,
        tags: s.tags.map(&:name),
        episodes: s.movies.map do |movie|
          {
            title: movie.title,
            description: movie.description,
            is_pro: movie.is_pro,
            release_date: movie.release_date,
            tags: movie.tags.map(&:name)
          }
        end
      }
    end
    render json: { series: result }
  end

  # 3. Endpoint to return user and AI responses for each user interaction
  def history
    if current_user
      chats = Chat.where(user: current_user).order(:created_at)
    else
      chats = []
    end
    result = chats.map do |chat|
      {
        user_message: chat.user_message,
        ai_response: chat.ai_response,
        created_at: chat.created_at
      }
    end
    render json: { history: result }
  end
end
