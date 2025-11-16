require 'sidekiq/web'

Rails.application.routes.draw do
  get "users/index"
  unauthenticated do
    root to: "static_pages#top"
  end

  authenticated :user do
    root to: "home#index", as: :authenticated_root
    resources :recordings, only: [ :index ]
    resources :videos, only: [ :index, :new, :create, :destroy ] do
      collection do
        get :search
      end
    end
    resources :guidelines, only: [ :index ]
    resources :video_generations, only: [ :index ]
    namespace :admin do
      resources :dashboards, only: %i[index]
    end
  end

  authenticated :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/admin/sidekiq'   
  end

  
  devise_for :users, only: [ :sessions, :registrations ], controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  get "home/index"
  
  resources :users, only: [ :index ]
  

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
end
