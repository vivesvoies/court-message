Rails.application.routes.draw do
  root "conversations#index"

  devise_for :users

  resources :contacts, only: [:show, :new, :edit, :create, :update, :destroy]
  resources :conversations, only: [:index, :show]
  resources :messages, only: [:new, :create]
  resources :inbound_messages, only: [:create]
  resources :outbound_messages, only: [:create]
end
