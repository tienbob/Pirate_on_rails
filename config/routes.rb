Rails.application.routes.draw do
  # PWA files
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Devise routes for User authentication
  devise_for :users, sign_out_via: [:get, :delete]


  # Root path: movies#index for authenticated users, login for unauthenticated
devise_scope :user do
  authenticated :user do
    root to: "movies#index", as: :authenticated_root
  end

  unauthenticated do
    root to: "devise/sessions#new", as: :unauthenticated_root
  end
end

  resources :movies do
    collection do
      get 'search'
    end
  end
  resources :tags
  get 'payments/upgrade', to: 'payments#upgrade', as: :upgrade_payment
  resources :payments
  resources :users, only: [:index, :new, :create, :show, :update, :destroy]
  get 'payments/success', to: 'payments#success', as: :success_payments
  post 'payments/create_checkout_session', to: 'payments#create_checkout_session', as: :create_checkout_session_payments
  post 'payments/create_portal_session', to: 'payments#create_portal_session', as: :create_portal_session_payments
  post 'payments/webhook', to: 'payments#webhook', as: :webhook_payments
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

