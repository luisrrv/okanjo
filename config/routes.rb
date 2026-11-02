Rails.application.routes.draw do
  root "groups#new"

  # Always nested under the token, never shallow: ids are guessable, tokens aren't.
  resources :groups, only: %i[create show], param: :token do
    resources :members, only: %i[create destroy]
    resource :identity, only: %i[create destroy]
    resources :expenses, only: %i[new create edit update destroy]
    resource :receipt, only: :show
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
