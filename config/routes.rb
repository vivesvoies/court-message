Rails.application.routes.draw do
  root to: redirect("/teams")

  get "/.internal/ui", to: "pages#show", id: "ui"
  resources :pages, only: [ :show ]

  authenticate :user, ->(user) { Ability.new(user).can?(:manage, Team) } do
    mount Avo::Engine, at: Avo.configuration.root_path
  end

  # User-facing routes
  devise_for :users, controllers: { registrations: "registrations" }
  devise_scope :user do
    get "/users/await-confirmation", to: "registrations#show", as: :await_confirmation
  end

  resources :messages, only: [ :new, :create ]
  resources :teams, only: [ :index, :show, :edit, :update ] do
    member do
      get :menu, to: "teams#menu"
    end

    resources :conversations, only: [ :index, :show ] do
      member do
        patch :status, to: "read_status#update", as: :read_status
      end
    end
    resources :contacts, only: [ :index, :show, :new, :edit, :create, :update, :destroy ]
    resources :users, only: [ :show, :edit, :update ]
    devise_for :users, controllers: { invitations: "invitations" }
  end
  resources :memberships, only: [ :new, :create, :destroy ]

  # Messaging services routes
  resources :inbound_messages, only: [ :create ]
  resources :outbound_messages, only: [ :create ]
end
