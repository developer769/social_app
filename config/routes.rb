Rails.application.routes.draw do
  # ---- Authentication ------------------------------------------------------
  get    "login",  to: "sessions#new", as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"

  # ---- Workspace selection -------------------------------------------------
  resources :workspaces, only: %i[index]

  # ---- Workspace-scoped ----------------------------------------------------
  # The slug is a lookup key only. Access resolves from the signed-in user's
  # own accepted membership, so another workspace's slug simply 404s (spec 7).
  scope "/w/:workspace_slug", as: :workspace do
    root to: "dashboard#show", as: :root
  end

  get "up", to: "rails/health#show", as: :rails_health_check

  root to: "sessions#new"
end
