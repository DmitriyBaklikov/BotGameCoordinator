module Commands
  class PublicGamesHandler
    PAGE_SIZE = 5

    def self.call(controller, user, page: 0, filters: {})
      locale = user.locale.to_sym
      games  = build_query(filters).limit(PAGE_SIZE).offset(page * PAGE_SIZE)
      total  = build_query(filters).count

      if games.empty?
        controller.send_message(controller.from.id, I18n.t("bot.no_public_games", locale: locale))
        return
      end

      games.each do |game|
        card = TelegramMessageBuilder.event_card(game, locale: locale, time_zone: user.tz)
        controller.send_message(controller.from.id, card[:text],
                                reply_markup: TelegramMessageBuilder.vote_keyboard(game, locale: locale))
      end

      if (page + 1) * PAGE_SIZE < total
        controller.send_message(
          controller.from.id,
          I18n.t("bot.more_games_available", count: total - ((page + 1) * PAGE_SIZE), locale: locale),
          reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
            inline_keyboard: [[
              Telegram::Bot::Types::InlineKeyboardButton.new(
                text:          I18n.t("bot.load_more", locale: locale),
                callback_data: "publicgames:page:#{page + 1}"
              )
            ]]
          )
        )
      end
    end

    def self.build_query(filters)
      query = Game.public_active.includes(:location, :organizer)

      query = query.where(sport_type: filters[:sport_type]) if filters[:sport_type].present?
      query = query.joins(:location).where(locations: { name: filters[:location_name] }) if filters[:location_name].present?
      query = query.joins(:organizer).where(users: { username: filters[:organizer_username] }) if filters[:organizer_username].present?

      query.order(:scheduled_at)
    end
  end
end
