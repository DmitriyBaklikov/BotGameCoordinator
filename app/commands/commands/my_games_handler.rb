module Commands
  class MyGamesHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      games = Game.active_for_organizer(user.id).includes(:location, :game_participants).order(:scheduled_at)

      if games.empty?
        controller.send_message(controller.from.id, I18n.t("bot.no_active_games", locale: locale))
        return
      end

      games.each do |game|
        card = TelegramMessageBuilder.event_card(game, locale: locale, time_zone: user.tz)
        manage_keyboard = TelegramMessageBuilder.manage_game_keyboard(game, locale: locale)
        controller.send_message(controller.from.id, card[:text], reply_markup: manage_keyboard)
      end
    end
  end
end
