Rails.application.routes.draw do
  get  "/health", to: "health#show"
  post "/health", to: "health#post"

  # Telegram webhook endpoint (preferred: configure Telegram to POST here).
  post "/telegram_webhook", to: "telegram_webhooks#webhook"
  # Backward-compatible alias in case the Telegram webhook was configured to "/".
  post "/", to: "telegram_webhooks#webhook"

  namespace :admin do
    mount GoodJob::Engine => '/good_job'
    resources :users,         only: [:index, :show, :update]
    resources :games,         only: [:index, :show, :update]
    resources :subscriptions, only: [:index, :destroy]
    root to: "games#index"
  end
end

