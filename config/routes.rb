Rails.application.routes.draw do
  # Public status page, its JSON summary, the README badges and the incident feed.
  root "status#show"
  get "status", to: "status#show", format: true, constraints: { format: :json }, as: :status_summary
  get "badge/:id", to: "badges#show", format: true, constraints: { format: :svg, id: /\d+/ }, as: :badge
  get "incidents", to: "incident_feeds#show", format: true, constraints: { format: :atom }, as: :incidents_feed

  # E-mail subscriptions with double opt-in.
  resources :subscribers, only: :create
  get "subscription/confirm/:token", to: "subscription_confirmations#show", as: :subscription_confirmation
  post "subscription/confirm/:token", to: "subscription_confirmations#create"
  get "subscription/unsubscribe/:token", to: "unsubscribes#show", as: :unsubscribe
  post "subscription/unsubscribe/:token", to: "unsubscribes#create"

  # Sign-in (no public sign-up) and the admin screens.
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root to: redirect("/admin/monitors")
    resources :monitors do
      post :check, on: :member
    end
    resources :incidents do
      resources :updates, only: :create, controller: "incident_updates"
    end
    resources :subscribers, only: %i[index destroy]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
