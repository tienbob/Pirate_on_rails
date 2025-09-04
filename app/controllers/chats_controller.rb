class ChatsController < ApplicationController
  include Searchable
  before_action :authenticate_user!, except: [ :series_data ]
  protect_from_forgery with: :null_session

  # 1. User chat message comes in
  def create
    user_message = params[:message]

    begin
      python_ai_url = ENV["PYTHON_AI_URL"] || "http://python-ai:8000"
      timeout = ENV["AI_SERVICE_TIMEOUT"]&.to_i || 120

      connection = Faraday.new(url: python_ai_url) do |f|
        f.options.timeout = timeout
        f.options.open_timeout = 10
      end

      response = connection.post("/chat", {
        message: user_message,
        user_id: current_user&.id&.to_s
      }.to_json, "Content-Type" => "application/json")
      ai_response = JSON.parse(response.body)["response"] rescue "Sorry, I couldn't process your request."
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED => e
      Rails.logger.error "AI service connection failed: #{e.message}"
      ai_response = "Sorry, the AI service is currently unavailable. Please try again later."
    rescue Faraday::TimeoutError => e
      Rails.logger.error "AI service timeout: #{e.message}"
      ai_response = "Sorry, the AI service is taking too long to respond. Please try again."
    rescue => e
      Rails.logger.error "Unexpected error in chat: #{e.message}"
      ai_response = "Sorry, something went wrong. Please try again."
    end

    chat = Chat.create!(user_message: user_message, ai_response: ai_response, user: current_user)

    # Broadcast to Action Cable
    ChatChannel.broadcast_to(current_user, {
      user_message: chat.user_message,
      ai_response: chat.ai_response,
      created_at: chat.created_at
    })

    render json: { response: ai_response }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to save chat: #{e.message}"
    render json: { response: "Sorry, couldn't save your message. Please try again." }
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
