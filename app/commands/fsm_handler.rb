class FsmHandler
  def self.handle(controller, user, text)
    state = controller.read_fsm_state(user.id)
    return unless state

    case state[:step]
    when "datetime"
      GameCreator.handle_text(user, controller, text)
    when "location_name"
      GameCreator.handle_text(user, controller, text)
    when "max_participants"
      GameCreator.handle_text(user, controller, text)
    when "min_participants"
      GameCreator.handle_text(user, controller, text)
    when "relaunch_datetime"
      GameCreator.handle_text(user, controller, text)
    when "invite_username"
      handle_invite_username(controller, user, text, state[:data])
    when "search_subscriptions"
      handle_subscription_search(controller, user, text, :my_subs)
    when "search_organizers"
      handle_subscription_search(controller, user, text, :organizers)
    when "preset_datetime"
      handle_preset_datetime(controller, user, text, state[:data])
    when "preset_edit_max", "preset_manage_edit_max"
      handle_preset_edit_max(controller, user, text, state)
    when "preset_edit_min", "preset_manage_edit_min"
      handle_preset_edit_min(controller, user, text, state)
    when "preset_edit_location_name", "preset_manage_edit_location_name"
      handle_preset_edit_location_name(controller, user, text, state)
    when "preset_add_invitee"
      handle_preset_add_invitee(controller, user, text, state[:data])
    end
  end

  def self.handle_invite_username(controller, user, text, data)
    game_id = data[:game_id] || data["game_id"]
    game    = Game.find_by(id: game_id)
    locale  = user.locale.to_sym

    unless game
      controller.send_message(user.telegram_id, I18n.t("bot.game_not_found", locale: locale))
      controller.clear_fsm_state(user.id)
      return
    end

    username = text.delete_prefix("@").strip
    invitee  = User.find_by(username: username)

    if invitee
      result = InvitationService.create(game: game, inviter: user, invitee: invitee)
      if result[:error]
        controller.send_message(user.telegram_id, I18n.t("bot.#{result[:error]}", locale: locale, username: username))
      else
        controller.send_message(user.telegram_id, I18n.t("bot.invitation_sent", name: invitee.display_name, locale: locale))
      end
    else
      result = InvitationService.create_for_unknown_user(game: game, inviter: user, invitee_username: username)
      if result[:error]
        controller.send_message(user.telegram_id, I18n.t("bot.#{result[:error]}", locale: locale, username: username))
      elsif result[:invitation]
        SendInvitationJob.perform_later(game.id, user.id, nil, result[:invitation].id)
      end
    end

    controller.clear_fsm_state(user.id)
  end

  def self.handle_subscription_search(controller, user, text, list_type)
    search_query = text.strip
    controller.clear_fsm_state(user.id)
    Commands::SettingsHandler.show_search_results(controller, user, search_query, list_type, page: 0)
  end

  def self.handle_preset_datetime(controller, user, text, data)
    locale = user.locale.to_sym
    scheduled_at = GameCreator.send(:parse_datetime, text, user.tz)

    unless scheduled_at
      controller.send_message(user.telegram_id, I18n.t("bot.invalid_datetime_format", locale: locale))
      return
    end

    unless scheduled_at > Game::MIN_HOURS_BEFORE_GAME.hours.from_now
      controller.send_message(user.telegram_id, I18n.t("bot.datetime_too_soon", hours: Game::MIN_HOURS_BEFORE_GAME, locale: locale))
      return
    end

    data = data.merge(scheduled_at: scheduled_at.iso8601)
    controller.clear_fsm_state(user.id)
    game = GameCreator.finish(user, controller, data)

    if game
      preset_id = data[:preset_id] || data["preset_id"]
      preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id) if preset_id

      if preset&.game_preset_invitees&.any?
        invitee_names = preset.game_preset_invitees.map { |i| "@#{i.username}" }.join(", ")
        fsm_data = data.merge(created_game_id: game.id)
        controller.write_fsm_state(user.id, step: "preset_confirm_invitees", data: fsm_data)
        controller.send_message(
          user.telegram_id,
          I18n.t("bot.presets.confirm_invitees", list: invitee_names, locale: locale),
          reply_markup: TelegramMessageBuilder.preset_confirm_invitees_keyboard(locale: locale)
        )
      end
    end
  end

  def self.handle_preset_edit_max(controller, user, text, state)
    locale = user.locale.to_sym
    max = text.to_i

    unless max.between?(2, 100)
      controller.send_message(user.telegram_id, I18n.t("bot.invalid_max_participants", locale: locale))
      return
    end

    data = state[:data].merge(max_participants: max)
    manage_mode = state[:step].start_with?("preset_manage")
    preset_id = data[:editing_preset_id] || data["editing_preset_id"]

    if manage_mode && preset_id
      PresetService.update_field(GamePreset.find(preset_id), :max_participants, max)
    end

    step = manage_mode ? "preset_manage_edit_menu" : "preset_edit_menu"
    controller.write_fsm_state(user.id, step: step, data: data)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.presets.select_field", locale: locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
    )
  end

  def self.handle_preset_edit_min(controller, user, text, state)
    locale = user.locale.to_sym
    min = text.to_i
    max = (state[:data][:max_participants] || state[:data]["max_participants"]).to_i

    unless min.between?(1, max)
      controller.send_message(user.telegram_id, I18n.t("bot.invalid_min_participants", max: max, locale: locale))
      return
    end

    data = state[:data].merge(min_participants: min)
    manage_mode = state[:step].start_with?("preset_manage")
    preset_id = data[:editing_preset_id] || data["editing_preset_id"]

    if manage_mode && preset_id
      PresetService.update_field(GamePreset.find(preset_id), :min_participants, min)
    end

    step = manage_mode ? "preset_manage_edit_menu" : "preset_edit_menu"
    controller.write_fsm_state(user.id, step: step, data: data)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.presets.select_field", locale: locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
    )
  end

  def self.handle_preset_edit_location_name(controller, user, text, state)
    locale = user.locale.to_sym
    location = Location.find_or_create_by!(organizer: user, name: text.strip)
    data = state[:data].merge(location_id: location.id, location_name: text.strip)
    manage_mode = state[:step].start_with?("preset_manage")
    preset_id = data[:editing_preset_id] || data["editing_preset_id"]

    if manage_mode && preset_id
      PresetService.update_field(GamePreset.find(preset_id), :location_id, location.id)
    end

    step = manage_mode ? "preset_manage_edit_menu" : "preset_edit_menu"
    controller.write_fsm_state(user.id, step: step, data: data)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.presets.select_field", locale: locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: locale)
    )
  end

  def self.handle_preset_add_invitee(controller, user, text, data)
    locale = user.locale.to_sym
    preset_id = data[:editing_preset_id] || data["editing_preset_id"]
    preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id)

    unless preset
      controller.clear_fsm_state(user.id)
      return
    end

    username = text.delete_prefix("@").strip
    invitee_user = User.find_by(username: username)

    GamePresetInvitee.create!(
      game_preset: preset,
      user: invitee_user,
      username: username
    )

    controller.send_message(user.telegram_id, I18n.t("bot.presets.invitee_added", username: username, locale: locale))

    preset.reload
    controller.write_fsm_state(user.id, step: "preset_add_invitee", data: data)
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.presets.field_invitees", locale: locale),
      reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: locale)
    )
  end
end
