Rails.application.routes.draw do
  post "/", to: "health#post"
  telegram_webhook TelegramWebhooksController
end

