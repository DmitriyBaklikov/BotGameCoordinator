module Commands
  class NewGameHandler
    def self.call(controller, user)
      locale = user.locale.to_sym

      unless user.organizer?
        controller.send_message(controller.from.id, I18n.t("bot.not_authorized", locale: locale))
        return
      end

      active_count = Game.active_for_organizer(user.id).count

      if active_count >= Game::ACTIVE_EVENTS_LIMIT
        send_limit_warning(controller, user, locale)
        return
      end

      presets = user.game_presets.includes(:location)
      if presets.any?
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.presets.choose_prompt", locale: locale),
          reply_markup: TelegramMessageBuilder.choose_preset_keyboard(presets, locale: locale)
        )
      else
        start_fresh(controller, user)
      end
    end

    def self.start_fresh(controller, user)
      GameCreator.start(user, controller)
    end

    def self.send_limit_warning(controller, user, locale)
      active_games = Game.active_for_organizer(user.id).includes(:location).to_a

      buttons = active_games.map do |game|
        [Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          "🗄 #{game.title} — #{game.scheduled_at.in_time_zone(user.tz).strftime('%d.%m %H:%M')}",
          callback_data: "archive_game:#{game.id}"
        )]
      end

      controller.send_message(
        controller.from.id,
        I18n.t("bot.active_event_limit_reached", locale: locale),
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
      )
    end
  end
end
