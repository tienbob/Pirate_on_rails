Rails.application.routes.draw do
  resources :series
  # PWA files
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Devise routes for User authentication
  devise_for :users, sign_out_via: [:get, :delete]
  # Mount Action Cable at /cable for WebSocket support
  mount ActionCable.server => '/cable'

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
  end
  
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
  get 'payments/upgrade', to: 'payments#upgrade', as: :upgrade_payment
  get 'payments/success', to: 'payments#success', as: :success_payments
  get 'payments/cancel', to: 'payments#cancel', as: :cancel_payment
  get 'payments/manage', to: 'payments#manage_subscription', as: :manage_subscription
  post 'payments/cancel_subscription', to: 'payments#cancel_subscription', as: :cancel_subscription
  resources :users, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  resources :payments, only: [:index, :show, :new, :create]
  post 'payments/create_checkout_session', to: 'payments#create_checkout_session', as: :create_checkout_session_payments
  post 'payments/create_portal_session', to: 'payments#create_portal_session', as: :create_portal_session_payments
  post 'payments/webhook', to: 'payments#webhook', as: :webhook_payments  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  post "/chats", to: "chats#create"
  get "/chats/movies_data", to: "chats#movies_data"
  get "/chats/history", to: "chats#history"
  get "/chats/series_data", to: "chats#series_data"

end

