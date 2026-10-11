Rails.application.routes.draw do
  # Development only: use "localhost" rather than 127.0.0.1 so the page and the
  # Vite dev server share an origin. In production this would hijack any request
  # that reaches the app by IP address, health checks included.
  if Rails.env.development?
    constraints(host: "127.0.0.1") do
      get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
    end
  end

  root "assessments#index"
  resources :assessments, only: %i[index create update]

  resources :exports, only: %i[index create] do
    collection { get :preview }
    member do
      get :download
      post :retry
    end
  end

  post "assistant", to: "assistants#create"

  get "safeguards", to: "safeguards#show"
  get "release_plan", to: "release_plans#show"
  get "release_plan/normalize", to: "release_plans#normalize"

  # Active Storage's other routes are switched off (see config/application.rb); the
  # Disk service still needs its signed, short-lived download link.
  get "/rails/active_storage/disk/:encoded_key/*filename", to: "active_storage/disk#show", as: :rails_disk_service

  resource :session, only: %i[new create destroy]
  resource :captcha, only: :show
  get "captcha/question", to: "captchas#question", as: :captcha_question
  resource :cookie_consent, only: :create

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
