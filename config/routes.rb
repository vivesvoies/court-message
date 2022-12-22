Rails.application.routes.draw do
  root "conversations#index"

  resources :users
  resources :conversations
  resources :messages, only: [:new, :create]
  resources :inbound_messages, only: [:create]
  resources :outbound_messages, only: [:create]
end
