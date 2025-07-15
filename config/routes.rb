Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA files
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Devise routes for User authentication
  devise_for :users


  # Root path: movies#index for authenticated users, login for unauthenticated
  authenticated :user do
    root to: "movies#index", as: :authenticated_root
  end

  unauthenticated do
    root to: "devise/sessions#new", as: :unauthenticated_root
  end

  resources :movies
  resources :tags
  resources :payments
  resources :users, only: [:index, :show, :new, :create]
end
