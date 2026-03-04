module Commands
  class ArchiveHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      games = user.games.where(status: %i[cancelled archived]).order(scheduled_at: :desc).limit(20)

      if games.empty?
        controller.send_message(controller.from.id, I18n.t("bot.no_archived_games", locale: locale))
        return
      end

      controller.send_message(controller.from.id, I18n.t("bot.archived_games_header", locale: locale))

      games.each do |game|
        card     = TelegramMessageBuilder.event_card(game, locale: locale, time_zone: user.tz)
        keyboard = TelegramMessageBuilder.archive_game_keyboard(game, locale: locale)
        controller.send_message(controller.from.id, card[:text], reply_markup: keyboard)
      end
    end
  end
end
