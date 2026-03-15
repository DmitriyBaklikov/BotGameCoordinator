class NotificationService
  def self.notify_cancellation(game)
    locale    = :en
    going_ids = game.game_participants.going.includes(:user).map(&:user)
    organizer = game.organizer

    recipients = (going_ids + [organizer]).uniq

    recipients.each do |user|
      user_locale = user.locale.to_sym
      send_dm(
        user.telegram_id,
        I18n.t(
          "notifications.cancellation",
          title: game.title,
          date:  game.scheduled_at.in_time_zone(user.tz).strftime("%d.%m.%Y %H:%M"),
          locale: user_locale
        )
      )
    end
  end

  def self.notify_removal(user, game)
    locale = user.locale.to_sym
    send_dm(
      user.telegram_id,
      I18n.t("notifications.removed_from_game", title: game.title, locale: locale)
    )
  end

  def self.notify_reserve_promotion(user, game)
    locale   = user.locale.to_sym
    keyboard = TelegramMessageBuilder.reserve_promotion_keyboard(game, locale: locale)
    send_dm(
      user.telegram_id,
      I18n.t("notifications.reserve_promotion", title: game.title, date: game.scheduled_at.in_time_zone(user.tz).strftime("%d.%m.%Y %H:%M"), locale: locale),
      reply_markup: keyboard
    )
  end

  def self.notify_new_game(user, game)
    locale   = user.locale.to_sym
    card     = TelegramMessageBuilder.event_card(game, locale: locale, time_zone: user.tz)
    keyboard = TelegramMessageBuilder.vote_keyboard(game, locale: locale)
    send_dm(
      user.telegram_id,
      "#{I18n.t("notifications.new_game", organizer: game.organizer.display_name, locale: locale)}\n\n#{card[:text]}",
      reply_markup: keyboard
    )
  end

  def self.notify_invite_declined(organizer, invitee, game)
    locale = organizer.locale.to_sym
    send_dm(
      organizer.telegram_id,
      I18n.t("notifications.invite_declined",
             name:  invitee.display_name,
             title: game.title,
             locale: locale)
    )
  end

  def self.send_invitation_dm(invitee, game, invitation)
    locale   = invitee.locale.to_sym
    keyboard = TelegramMessageBuilder.invite_keyboard(invitation, locale: locale)
    markup   = keyboard.respond_to?(:to_h) && !keyboard.is_a?(Hash) ? keyboard.to_h : keyboard
    bot_instance.send_message(
      chat_id:      invitee.telegram_id,
      text:         I18n.t("notifications.invitation",
                           organizer: game.organizer.display_name,
                           title:     game.title,
                           date:      game.scheduled_at.in_time_zone(invitee.tz).strftime("%d.%m.%Y %H:%M"),
                           locale:    locale),
      parse_mode:   "HTML",
      reply_markup: markup
    )
    true
  rescue Telegram::Bot::Error => e
    Rails.logger.error("[NotificationService] Failed to send invitation DM to #{invitee.telegram_id}: #{e.message}")
    false
  end

  def self.notify_inviter_dm_sent(inviter, invitee)
    locale = inviter.locale.to_sym
    send_dm(
      inviter.telegram_id,
      I18n.t("bot.invitation_sent_dm", name: invitee.display_name, locale: locale)
    )
  end

  def self.notify_inviter_deep_link(inviter, invitee_name, link)
    locale = inviter.locale.to_sym
    send_dm(
      inviter.telegram_id,
      I18n.t("bot.invitation_sent_link", name: invitee_name, link: link, locale: locale)
    )
  end

  class << self
    private

    def send_dm(telegram_id, text, **opts)
      opts[:reply_markup] = opts[:reply_markup].to_h if opts[:reply_markup].respond_to?(:to_h) && !opts[:reply_markup].is_a?(Hash)
      bot_instance.send_message(chat_id: telegram_id, text: text, parse_mode: "HTML", **opts)
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[NotificationService] Failed to send DM to #{telegram_id}: #{e.message}")
    end

    def bot_instance
      token = Rails.application.config.telegram_bot_token.presence || ENV["TELEGRAM_BOT_TOKEN"]
      raise "TELEGRAM_BOT_TOKEN not configured" if token.blank?
      @bot_instance ||= Telegram::Bot::Client.new(token)
    end
  end
end
