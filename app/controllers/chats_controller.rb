class ChatsController < ApplicationController
  include Searchable
  protect_from_forgery with: :null_session

  # 1. User chat message comes in
  def create
    user_message = params[:message]
    # Send only the message to Python agent
    response = Faraday.post("http://localhost:5000/chat", { message: user_message }.to_json, "Content-Type" => "application/json")
    ai_response = JSON.parse(response.body)["response"] rescue "Sorry, AI service unavailable."
    Chat.create!(user_message: user_message, ai_response: ai_response, user: current_user)
    render json: { response: ai_response }
  end

  # 2. Python agent can call this endpoint to search movies (using existing ES logic)
  def search
    movies = search_movies(params).limit(10)
    result = movies.as_json(only: [:title, :description])
    render json: { movies: result }
  end
end
