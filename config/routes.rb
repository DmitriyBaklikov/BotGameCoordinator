Rails.application.routes.draw do
  post "/", to: "health#post"

  telegram_webhook TelegramWebhooksController if Telegram.bots_config.present?

  namespace :admin do
    resources :users,         only: [:index, :show, :update]
    resources :games,         only: [:index, :show, :update]
    resources :subscriptions, only: [:index, :destroy]
    root to: "games#index"
  end
end

