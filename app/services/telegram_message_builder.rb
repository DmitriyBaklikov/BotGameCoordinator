class TelegramMessageBuilder
  def self.event_card(game, locale: :en, time_zone: nil)
    locale = locale.to_sym
    going_count   = game.game_participants.going.count
    maybe_count   = game.game_participants.maybe.count
    reserve_count = game.game_participants.reserve.count

    display_time = time_zone ? game.scheduled_at.in_time_zone(time_zone) : game.scheduled_at

    text = <<~HTML
      <b>#{game.title}</b>
      📅 #{display_time.strftime("%d.%m.%Y %H:%M")}
      📍 #{game.location.name}#{game.location.address ? " (#{game.location.address})" : ""}
      👤 #{I18n.t("game.organizer", locale: locale)}: #{game.organizer.display_name}
      ✅ #{I18n.t("game.going", locale: locale)}: #{going_count}/#{game.max_participants}
      🤔 #{I18n.t("game.maybe", locale: locale)}: #{maybe_count}
      ⏳ #{I18n.t("game.reserve", locale: locale)}: #{reserve_count}
      📊 #{I18n.t("game.status.#{game.status}", locale: locale)}
    HTML

    text += "\n🔒 #{I18n.t("game.visibility.private", locale: locale)}" if game.private_game?

    { text: text.strip }
  end

  def self.vote_keyboard(game, locale: :en)
    locale        = locale.to_sym
    going_count   = game.game_participants.going.count
    maybe_count   = game.game_participants.maybe.count

    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("game.going", locale: locale)} (#{going_count})",
            callback_data: "vote:going:#{game.id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🤔 #{I18n.t("game.maybe", locale: locale)} (#{maybe_count})",
            callback_data: "vote:maybe:#{game.id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("game.not_going", locale: locale)}",
            callback_data: "vote:not_going:#{game.id}"
          )
        ]
      ]
    )
  end

  def self.sport_type_keyboard(locale: :en)
    locale  = locale.to_sym
    sports  = Game.sport_types.keys
    buttons = sports.each_slice(2).map do |pair|
      pair.map do |sport|
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text:          I18n.t("game.sport_types.#{sport}", locale: locale),
          callback_data: "fsm:sport_type:#{sport}"
        )
      end
    end

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.event_type_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("game.event_types.game", locale: locale),
            callback_data: "fsm:event_type:game"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("game.event_types.training", locale: locale),
            callback_data: "fsm:event_type:training"
          )
        ]
      ]
    )
  end

  def self.location_keyboard(locations, locale: :en)
    locale  = locale.to_sym
    buttons = locations.map do |loc|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          "📍 #{loc.name}",
        callback_data: "fsm:location_id:#{loc.id}"
      )]
    end

    buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.new_location", locale: locale),
      callback_data: "fsm:location_id:new"
    )]

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.visibility_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🌍 #{I18n.t("game.visibility.public", locale: locale)}",
            callback_data: "fsm:visibility:public_game"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🔒 #{I18n.t("game.visibility.private", locale: locale)}",
            callback_data: "fsm:visibility:private_game"
          )
        ]
      ]
    )
  end

  def self.confirmation_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.confirm", locale: locale)}",
            callback_data: "fsm:confirm:yes"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.cancel", locale: locale)}",
            callback_data: "fsm:confirm:no"
          )
        ]
      ]
    )
  end

  def self.manage_game_keyboard(game, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "👥 #{I18n.t("bot.manage.participants", locale: locale)}",
            callback_data: "manage_game:participants:#{game.id}"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✋ #{I18n.t("bot.manage.self_vote", locale: locale)}",
            callback_data: "manage_game:self_vote:#{game.id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "📨 #{I18n.t("bot.manage.invite", locale: locale)}",
            callback_data: "manage_game:invite:#{game.id}"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🗄 #{I18n.t("bot.manage.archive", locale: locale)}",
            callback_data: "archive_game:#{game.id}"
          )
        ]
      ]
    )
  end

  def self.archive_game_keyboard(game, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "🔁 #{I18n.t("bot.relaunch", locale: locale)}",
            callback_data: "relaunch:#{game.id}"
          )
        ]
      ]
    )
  end

  def self.participant_list(game, locale: :en)
    locale   = locale.to_sym
    going    = game.game_participants.going.includes(:user)
    maybe    = game.game_participants.maybe.includes(:user)
    reserve  = game.game_participants.reserve.includes(:user)

    lines = ["<b>#{game.title}</b>\n"]

    lines << "✅ #{I18n.t("game.going", locale: locale)}:"
    going.each_with_index do |gp, idx|
      lines << "  #{idx + 1}. #{gp.user.display_name}"
    end
    lines << "" if maybe.any?

    if maybe.any?
      lines << "🤔 #{I18n.t("game.maybe", locale: locale)}:"
      maybe.each_with_index do |gp, idx|
        lines << "  #{idx + 1}. #{gp.user.display_name}"
      end
    end

    if reserve.any?
      lines << ""
      lines << "⏳ #{I18n.t("game.reserve", locale: locale)}:"
      reserve.each_with_index do |gp, idx|
        lines << "  #{idx + 1}. #{gp.user.display_name}"
      end
    end

    lines.join("\n")
  end

  def self.invite_keyboard(invitation, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.accept", locale: locale)}",
            callback_data: "invite_accept:#{invitation.id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.decline", locale: locale)}",
            callback_data: "invite_decline:#{invitation.id}"
          )
        ]
      ]
    )
  end

  def self.reserve_promotion_keyboard(game, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
            callback_data: "reserve_join:#{game.id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.no", locale: locale)}",
            callback_data: "reserve_decline:#{game.id}"
          )
        ]
      ]
    )
  end

  def self.choose_preset_keyboard(presets, locale: :en)
    locale = locale.to_sym
    buttons = presets.map do |preset|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          "📋 #{preset.name}",
        callback_data: "preset:select:#{preset.id}"
      )]
    end

    buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.presets.new_game_button", locale: locale),
      callback_data: "preset:new_game"
    )]

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.preset_change_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.presets.no_change", locale: locale),
            callback_data: "preset:no_change"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.presets.change_something", locale: locale),
            callback_data: "preset:change"
          )
        ]
      ]
    )
  end

  def self.preset_edit_menu_keyboard(preset_id, locale: :en)
    locale = locale.to_sym
    fields = %w[sport_type event_type location max_participants min_participants visibility invitees]
    buttons = fields.map do |field|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          I18n.t("bot.presets.field_#{field}", locale: locale),
        callback_data: "preset:edit_field:#{preset_id}:#{field}"
      )]
    end

    buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.presets.done", locale: locale),
      callback_data: "preset:edit_done:#{preset_id}"
    )]

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.preset_list_keyboard(presets, locale: :en)
    locale = locale.to_sym
    buttons = presets.map do |preset|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          "📋 #{preset.name}",
        callback_data: "preset:view:#{preset.id}"
      )]
    end

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.preset_actions_keyboard(preset_id, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.presets.edit", locale: locale),
            callback_data: "preset:manage_edit:#{preset_id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.presets.delete", locale: locale),
            callback_data: "preset:delete_confirm:#{preset_id}"
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          I18n.t("bot.presets.back", locale: locale),
            callback_data: "preset:manage_list"
          )
        ]
      ]
    )
  end

  def self.preset_delete_confirm_keyboard(preset_id, locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
            callback_data: "preset:delete_yes:#{preset_id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.no", locale: locale)}",
            callback_data: "preset:delete_no:#{preset_id}"
          )
        ]
      ]
    )
  end

  def self.save_preset_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
            callback_data: "preset:save_yes"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.no", locale: locale)}",
            callback_data: "preset:save_no"
          )
        ]
      ]
    )
  end

  def self.preset_replace_keyboard(presets, locale: :en)
    locale = locale.to_sym
    buttons = presets.map do |preset|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          "📋 #{preset.name}",
        callback_data: "preset:replace:#{preset.id}"
      )]
    end

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def self.preset_confirm_invitees_keyboard(locale: :en)
    locale = locale.to_sym
    Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "✅ #{I18n.t("bot.yes", locale: locale)}",
            callback_data: "preset:invitees_yes"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text:          "❌ #{I18n.t("bot.no", locale: locale)}",
            callback_data: "preset:invitees_no"
          )
        ]
      ]
    )
  end

  def self.preset_invitees_edit_keyboard(preset, locale: :en)
    locale = locale.to_sym
    buttons = preset.game_preset_invitees.map do |inv|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          "❌ @#{inv.username}",
        callback_data: "preset:remove_invitee:#{preset.id}:#{inv.id}"
      )]
    end

    buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          "➕ #{I18n.t("bot.manage.invite", locale: locale)}",
      callback_data: "preset:add_invitee:#{preset.id}"
    )]

    buttons << [Telegram::Bot::Types::InlineKeyboardButton.new(
      text:          I18n.t("bot.presets.done", locale: locale),
      callback_data: "preset:edit_done:#{preset.id}"
    )]

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end
end
