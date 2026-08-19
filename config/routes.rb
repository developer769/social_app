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

    resources :products, only: %i[create update destroy], module: :catalog
    resources :services, only: %i[create update destroy], module: :catalog

    resources :social_accounts, only: %i[create destroy], module: :connections

    # Resumable onboarding (spec 22). /onboarding redirects to wherever the
    # owner stopped; each step has its own addressable URL.
    get "onboarding", to: "onboarding/resume#show", as: :onboarding

    scope "onboarding", as: :onboarding do
      get   "business",    to: "onboarding/business#show",    as: :business
      patch "business",    to: "onboarding/business#update"
      get   "catalog",     to: "onboarding/catalog#show",     as: :catalog
      post  "catalog/continue", to: "onboarding/catalog#complete", as: :catalog_complete
      get   "connections", to: "onboarding/connections#show", as: :connections
      post  "connections/continue", to: "onboarding/connections#complete", as: :connections_complete
      get   "analysis",    to: "onboarding/analysis#show",    as: :analysis
      get   "health",      to: "onboarding/health#show",      as: :health
      get   "plan",        to: "onboarding/plan#show",        as: :plan
    end
  end

  get "up", to: "rails/health#show", as: :rails_health_check

  root to: "sessions#new"
end
