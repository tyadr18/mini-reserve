Rails.application.routes.draw do
  root "reservations#index"
  resources :reservations

  get "up" => "rails/health#show", as: :rails_health_check
end
