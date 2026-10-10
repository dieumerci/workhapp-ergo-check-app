Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  root "assessments#index"
  resources :assessments, only: %i[index update]

  resources :exports, only: %i[index create] do
    collection { get :preview }
    member do
      get :download
      post :retry
    end
  end

  get "safeguards", to: "safeguards#show"
  get "release_plan", to: "release_plans#show"
  get "release_plan/normalize", to: "release_plans#normalize"

  resource :session, only: %i[new create destroy]
  resource :captcha, only: :show
  resource :cookie_consent, only: :create

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
