Rails.application.routes.draw do
  # ---- Authentication ------------------------------------------------------
  get    "login",  to: "sessions#new", as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # ---- Invitations ---------------------------------------------------------
  get    "invitations/:token",         to: "invitations#show",    as: :invitation
  post   "invitations/:token/accept",  to: "invitations#accept",  as: :accept_invitation
  delete "invitations/:token/decline", to: "invitations#decline", as: :decline_invitation

  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"

  # ---- Workspace selection -------------------------------------------------
  resources :workspaces, only: %i[index new create]

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
    get "gallery",               to: "gallery/templates#index", as: :gallery
    get  "gallery/:slug",        to: "gallery/templates#show", as: :gallery_template
    post "gallery/:slug/use",    to: "gallery/uses#create",    as: :gallery_template_use

    # ---- Settings ----------------------------------------------------------
    namespace :settings do
      root to: "hub#show"
      resource  :business,     only: %i[show update], controller: "business"
      get       "catalog",     to: "catalog#show",    as: :catalog
      get       "connections", to: "connections#show", as: :connections
      resource  :security,     only: %i[show update], controller: "security"
      delete    "security/sessions/:id", to: "security#revoke_session", as: :security_session
      resource  :billing,      only: %i[show],        controller: "billing"
      resource  :posting_preferences, only: %i[show update], controller: "posting_preferences"
      resource  :brand_kit,    only: %i[show update], controller: "brand_kit"
      resource  :notifications, only: %i[show update], controller: "notifications"
      resources :team, only: %i[index create destroy] do
        member { post :resend }
        # Leaving is your own decision and needs no permission level, which is
        # exactly why it is a collection route and not a member one: you cannot
        # aim it at anybody else.
        collection { delete :leave }
      end
      get "activity", to: "activity#show", as: :activity
    end

    resources :creative_requests, only: [] do
      resources :selections, only: %i[create], controller: "posts/selections"
    end

    get "create", to: "create#show", as: :create
    get "analytics", to: "analytics#show", as: :analytics

    get "ads", to: "ads#show", as: :ads
    patch "ads/tracking", to: "ads#tracking", as: :ads_tracking
    resources :ad_campaigns, only: [] do
      resources :outcomes, only: %i[new create destroy], controller: "ad_outcomes"
    end

    get "inbox", to: "inbox#show", as: :inbox
    resources :conversations, only: %i[show] do
      member do
        post :reply
        patch :close
        patch :reopen
      end
    end
    resources :saved_replies, only: %i[index new create edit update destroy]

    get "calendar", to: "calendar#show", as: :calendar

    resources :posts, except: %i[index] do
      # Generating a picture for this post, and choosing between the results.
      resource :creative, only: %i[show new create], controller: "posts/creatives"

      member do
        patch :schedule
        patch :unschedule
        post  :cancel
      end
    end

    get "onboarding", to: "onboarding/resume#show", as: :onboarding

    scope "onboarding", as: :onboarding do
      get   "business",    to: "onboarding/business#show",    as: :business
      patch "business",    to: "onboarding/business#update"
      get   "catalog",     to: "onboarding/catalog#show",     as: :catalog
      post  "catalog/continue", to: "onboarding/catalog#complete", as: :catalog_complete
      get   "connections", to: "onboarding/connections#show", as: :connections
      post  "connections/continue", to: "onboarding/connections#complete", as: :connections_complete
      get   "analysis",    to: "onboarding/analysis#show",    as: :analysis
      post  "analysis",    to: "onboarding/analysis#create"
      post  "analysis/continue", to: "onboarding/analysis#complete", as: :analysis_complete
      get   "health",      to: "onboarding/health#show",      as: :health
      post  "health",      to: "onboarding/health#create"
      post  "health/continue", to: "onboarding/health#complete", as: :health_complete
      get   "plan",        to: "onboarding/plan#show",        as: :plan
      post  "plan",        to: "onboarding/plan#create"
    end
  end

  # ---- Staff area ----------------------------------------------------------
  # Entirely separate from the customer application: its own login, its own
  # session table, its own cookie. A customer account cannot reach it.
  namespace :admin do
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :templates, except: %i[destroy] do
      member do
        post :publish
        post :unpublish
        post :retire
      end
    end

    root to: "templates#index"
  end

  get "up", to: "rails/health#show", as: :rails_health_check

  root to: "sessions#new"
end
