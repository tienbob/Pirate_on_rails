Rails.application.routes.draw do
  # Prevent favicon.ico errors by returning 204 No Content
  get '/favicon.ico', to: proc { [204, {}, []] }
  # Health check endpoint for Docker and load balancers
  get '/health', to: 'application#health'
  
  resources :series
  # PWA files
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Devise routes for User authentication
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }, sign_out_via: [:get, :delete]
  # Mount Action Cable at /cable for WebSocket support
  mount ActionCable.server => '/cable'
  # Mount SubscriptionChannel for real-time updates
  mount ActionCable.server => '/subscriptions'

  devise_scope :user do
    authenticated :user do
      root to: "series#index", as: :authenticated_root
    end
  
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end

  resources :movies, except: [:index] do
    collection do
      get 'search'
    end
    # Video streaming route with direct path for better performance
    get 'video_stream', to: 'video_stream#show', as: :video_stream
  end
  
  # Direct video streaming route for maximum performance
  get '/stream/movie/:movie_id', to: 'video_stream#show', as: :direct_video_stream
  
  # API routes for analytics and tracking
  namespace :api do
    post 'track_view', to: 'analytics#track_view'
    resources :analytics, only: [] do
      collection do
        get 'dashboard'
        get 'movie_stats'
      end
    end
  end
  
  # Optionally, add a custom admin-only index if needed:
  # get 'movies', to: 'movies#index', as: :admin_movies, constraints: ->(req) { req.env['warden'].user&.admin? }
  resources :tags
  
  # Payment routes - custom actions before resources to avoid conflicts
  get 'payments/upgrade', to: 'payments#upgrade', as: :upgrade_payment
  get 'payments/success', to: 'payments#success', as: :success_payments
  get 'payments/cancel', to: 'payments#cancel', as: :cancel_payment
  get 'payments/manage', to: 'payments#manage_subscription', as: :manage_subscription
  post 'payments/cancel_subscription', to: 'payments#cancel_subscription', as: :cancel_subscription
  post 'payments/create_checkout_session', to: 'payments#create_checkout_session', as: :create_checkout_session_payments
  get 'payments/create_portal_session', to: 'payments#create_portal_session', as: :create_portal_session_payments
  post 'payments/create_portal_session', to: 'payments#create_portal_session'
  post 'payments/manual_sync', to: 'payments#manual_sync', as: :manual_sync_payments
  
  resources :users, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  resources :payments, only: [:index, :show, :new, :create]
  post 'payments/webhook', to: 'payments#webhook', as: :webhook_payments  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  post "/chats", to: "chats#create"
  get "/chats/movies_data", to: "chats#movies_data"
  get "/chats/history", to: "chats#history"
  get "/chats/series_data", to: "chats#series_data"

  # Static pages
  get '/about', to: 'pages#about', as: :about
  get '/contact', to: 'pages#contact', as: :contact

end

