module Commands
  class SettingsHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      controller.send_message(
        controller.from.id,
        I18n.t("bot.settings_menu", locale: locale),
        reply_markup: settings_keyboard(user, locale)
      )
    end

    def self.settings_keyboard(user, locale)
      Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: [
          [
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.settings.manage_subscriptions", locale: locale),
              callback_data: "settings:subscriptions"
            )
          ],
          [
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.settings.locale_en", locale: locale),
              callback_data: "settings:locale:en"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.settings.locale_ru", locale: locale),
              callback_data: "settings:locale:ru"
            )
          ]
        ]
      )
    end
  end
end
