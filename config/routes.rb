require "sidekiq/web"
require Rails.root.join("lib/single_user_access")

Sidekiq::Web.use Rack::Auth::Basic, "Put a Part" do |username, password|
  SingleUserAccess.valid?(username, password)
end

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "processing_runs#index"
  patch "locale/:locale", to: "locales#update", as: :locale
  resources :processing_runs, only: [ :index, :show, :create ] do
    get :download, on: :member
    post :cancel, on: :member
    post :reprocess, on: :member
  end
  mount Sidekiq::Web => "/sidekiq"
end
