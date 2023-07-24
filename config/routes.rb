Rails.application.routes.draw do
  root to: redirect("/conversations")

  devise_for :users

  resources :contacts, only: [:show, :new, :edit, :create, :update, :destroy]
  resources :conversations, only: [:index, :show] do
    member do
      get :detail, to: "conversations#show", defaults: { detail: true }
    end
  end
  resources :messages, only: [:new, :create]
  resources :inbound_messages, only: [:create]
  resources :outbound_messages, only: [:create]
  resources :teams, only: [:index, :show, :new, :edit, :create, :update, :destroy] do
    member do
      get :detail, to: "teams#show", defaults: { detail: true }
    end
  end
  resources :memberships, only: [:new, :create, :destroy]
end
