Rails.application.routes.draw do
  root "groups#new"

  # Accounts are optional (ADR 0022). The generator adds sessions and passwords; sign-up is ours.
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  # Always nested under the token, never shallow: ids are guessable, tokens aren't.
  resources :groups, only: %i[create show], param: :token do
    resources :members, only: %i[create destroy]
    resource :identity, only: %i[create destroy]
    resources :expenses, only: %i[new create edit update destroy]
    resource :receipt, only: :show
  end

  # The JSON API (ADR 0023): bearer tokens, its own controllers, the product's words.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :session, only: %i[create destroy]
      resource :me, only: :show, controller: :me
      namespace :me do
        resources :occasions, only: :index
      end
      resources :occasions, only: %i[create show], param: :token
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
