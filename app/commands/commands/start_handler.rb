module Commands
  class StartHandler
    def self.call(controller, user)
      user.update!(role: :organizer) unless user.organizer?

      controller.send_message(
        controller.from.id,
        I18n.t("bot.welcome", name: user.display_name, locale: user.locale.to_sym),
        reply_markup: main_menu_keyboard(user, controller)
      )
    end

    def self.main_menu_keyboard(user, controller)
      locale = user.locale.to_sym
      Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: [
          [
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.menu.new_game", locale: locale),
              callback_data: "menu:newgame"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.menu.my_games", locale: locale),
              callback_data: "menu:mygames"
            )
          ],
          [
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.menu.public_games", locale: locale),
              callback_data: "menu:publicgames"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text:          I18n.t("bot.menu.settings", locale: locale),
              callback_data: "menu:settings"
            )
          ]
        ]
      )
    end
  end
end
