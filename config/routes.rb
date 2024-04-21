Rails.application.routes.draw do
  root to: redirect("/teams")

  # Static pages
  get "/.internal/ui", to: "static_pages#ui", as: "ui" unless Rails.env.production?
  get "/terms_and_conditions", to: "static_pages#terms_and_conditions"
  get "/legal_notice", to: "static_pages#legal_notice"

  authenticate :user, ->(user) { Ability.new(user).can?(:manage, Team) } do
    mount Avo::Engine, at: Avo.configuration.root_path
  end

  # User-facing routes
  devise_for :users, controllers: { registrations: "registrations", invitations: "invitations" }
  devise_scope :user do
    get "/users/await-confirmation", to: "registrations#show", as: :await_confirmation
  end

  resources :messages, only: [ :new, :create ]
  resources :teams, only: [ :index, :show, :edit, :update ] do
    member do
      get :menu, to: "teams#menu"
    end

    resources :conversations, only: [ :index, :show, :new ] do
      member do
        patch :status, to: "read_status#update", as: :read_status
       end
    end
    resources :contacts, only: [ :index, :show, :new, :edit, :create, :update, :destroy ] do
      get :search, on: :collection
    end
    resources :users, only: [ :show, :edit, :update ] do
      resources :templates, only: [ :index, :new, :create, :edit, :update, :create, :destroy ]
    end
  end
  resources :memberships, only: [ :new, :create, :destroy ]

  # Messaging services routes
  resources :inbound_messages, only: [ :create ]
  resources :outbound_messages, only: [ :create ]
end
