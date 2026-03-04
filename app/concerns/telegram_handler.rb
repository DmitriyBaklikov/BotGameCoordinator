module TelegramHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_error
  end

  def send_message(chat_id, text, **opts)
    bot.send_message(
      chat_id: chat_id,
      text:    text,
      parse_mode: "HTML",
      **opts
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.error("[TelegramHandler] send_message failed: #{e.message}")
  end

  def send_message_to_current(text, **opts)
    send_message(chat.id, text, **opts)
  end

  def answer_callback(text = nil, show_alert: false)
    answer_callback_query(callback_query&.id, text: text, show_alert: show_alert)
  rescue StandardError => e
    Rails.logger.error("[TelegramHandler] answer_callback failed: #{e.message}")
  end

  def edit_message_text(chat_id, message_id, text, **opts)
    bot.edit_message_text(
      chat_id:    chat_id,
      message_id: message_id,
      text:       text,
      parse_mode: "HTML",
      **opts
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.warn("[TelegramHandler] edit_message_text failed: #{e.message}")
  end

  def t(key, **opts)
    locale = current_user_locale
    I18n.t(key, locale: locale, **opts)
  end

  def current_user_locale
    @current_user&.locale&.to_sym || :en
  end

  private

  def handle_error(error)
    Rails.logger.error("[TelegramHandler] Unhandled error: #{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}")
    send_message_to_current(I18n.t("bot.error_occurred")) rescue nil
  end
end
