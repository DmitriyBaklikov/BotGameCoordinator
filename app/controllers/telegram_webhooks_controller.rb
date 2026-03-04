class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def webhook
    token = Rails.application.config.telegram_bot_token.presence || ENV["TELEGRAM_BOT_TOKEN"]
    raise "TELEGRAM_BOT_TOKEN not configured" if token.blank?

    update = JSON.parse(request.raw_post)
    bot = Telegram::Bot::Client.new(token)

    TelegramBotController.dispatch(bot, update)
    head :ok
  end
end
