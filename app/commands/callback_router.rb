class CallbackRouter
  HANDLERS = {
    "menu"         => :handle_menu,
    "fsm"          => :handle_fsm,
    "cal"          => :handle_calendar,
    "vote"         => :handle_vote,
    "manage_game"  => :handle_manage_game,
    "archive_game" => :handle_archive_game,
    "relaunch"     => :handle_relaunch,
    "remove_participant" => :handle_remove_participant,
    "invite_accept"      => :handle_invite_accept,
    "invite_decline"     => :handle_invite_decline,
    "reserve_join"       => :handle_reserve_join,
    "reserve_decline"    => :handle_reserve_decline,
    "publicgames"        => :handle_public_games,
    "settings"           => :handle_settings,
    "preset"             => :handle_preset,
    "filter"             => :handle_filter
  }.freeze

  def self.dispatch(controller, user, data)
    parts  = data.to_s.split(":")
    action = parts[0]
    handler_method = HANDLERS[action]

    if handler_method
      new(controller, user, parts).public_send(handler_method)
    else
      controller.answer_callback(I18n.t("bot.unknown_action", locale: user.locale.to_sym))
    end
  end

  def initialize(controller, user, parts)
    @controller = controller
    @user       = user
    @parts      = parts
    @locale     = user.locale.to_sym
  end

  def handle_menu
    case @parts[1]
    when "newgame"    then Commands::NewGameHandler.call(@controller, @user)
    when "mygames"    then Commands::MyGamesHandler.call(@controller, @user)
    when "publicgames" then Commands::PublicGamesHandler.call(@controller, @user)
    when "settings"   then Commands::SettingsHandler.call(@controller, @user)
    end
    answer_callback
  end

  def handle_fsm
    state = @controller.read_fsm_state(@user.id)

    if state && (state[:step]&.start_with?("preset_edit_") || state[:step]&.start_with?("preset_manage_edit_"))
      handle_preset_fsm_callback(state, @parts[1], @parts[2])
    else
      GameCreator.handle_callback(@user, @controller, @parts[1], @parts[2])
    end
    answer_callback
  end

  def handle_vote
    vote_type = @parts[1].to_sym
    game_id   = @parts[2].to_i
    game      = Game.find_by(id: game_id)

    unless game
      answer_callback(I18n.t("bot.game_not_found", locale: @locale))
      return
    end

    result = ParticipantManager.vote(game: game, user: @user, vote: vote_type)
    answer_callback(result[:message])

    updated_card     = TelegramMessageBuilder.event_card(game.reload, locale: @locale, time_zone: @user.tz)
    updated_keyboard = TelegramMessageBuilder.vote_keyboard(game, locale: @locale)

    cb_message = @controller.payload&.dig("message")
    if cb_message
      chat_id    = cb_message.dig("chat", "id")
      message_id = cb_message["message_id"]
      @controller.edit_message_text(chat_id, message_id, updated_card[:text],
                                    reply_markup: updated_keyboard)
    end
  end

  def handle_manage_game
    action  = @parts[1]
    game_id = @parts[2].to_i
    game    = Game.find_by(id: game_id)
    return answer_callback unless game

    case action
    when "participants"
      text = TelegramMessageBuilder.participant_list(game, locale: @locale)
      @controller.send_message(@user.telegram_id, text)
    when "remove"
      participant_id = @parts[3].to_i
      ParticipantManager.remove(game: game, user: User.find_by(id: participant_id), remover: @user)
    when "self_vote"
      GameCreator.prompt_self_vote(@user, @controller, game)
    when "invite"
      @controller.send_message(@user.telegram_id,
                               I18n.t("bot.invite_username_prompt", locale: @locale))
      @controller.write_fsm_state(@user.id, step: "invite_username", data: { game_id: game_id })
    end

    answer_callback
  end

  def handle_archive_game
    game_id = @parts[1].to_i
    game    = Game.find_by(id: game_id)
    return answer_callback unless game
    return answer_callback unless game.organizer_id == @user.id

    game.update!(status: :archived)
    @controller.send_message(@user.telegram_id,
                             I18n.t("bot.game_archived", title: game.title, locale: @locale))
    answer_callback
  end

  def handle_relaunch
    game_id = @parts[1].to_i
    game    = Game.find_by(id: game_id)
    return answer_callback unless game
    return answer_callback unless game.organizer_id == @user.id

    GameCreator.start_relaunch(@user, @controller, game)
    answer_callback
  end

  def handle_remove_participant
    game_id        = @parts[1].to_i
    participant_id = @parts[2].to_i
    game           = Game.find_by(id: game_id)
    participant    = User.find_by(id: participant_id)

    return answer_callback unless game && participant

    ParticipantManager.remove(game: game, user: participant, remover: @user)
    answer_callback(I18n.t("bot.participant_removed", locale: @locale))
  end

  def handle_invite_accept
    invitation_id = @parts[1].to_i
    InvitationService.accept(invitation_id, @user, @controller)
    answer_callback
  end

  def handle_invite_decline
    invitation_id = @parts[1].to_i
    InvitationService.decline(invitation_id, @user, @controller)
    answer_callback
  end

  def handle_reserve_join
    game_id = @parts[1].to_i
    ParticipantManager.confirm_reserve(game_id: game_id, user: @user)
    answer_callback(I18n.t("bot.reserve_confirmed", locale: @locale))
  end

  def handle_reserve_decline
    game_id = @parts[1].to_i
    game    = Game.find_by(id: game_id)
    game&.game_participants&.find_by(user: @user)&.update!(status: :not_going)
    answer_callback(I18n.t("bot.reserve_declined", locale: @locale))
  end

  def handle_public_games
    page = @parts[2].to_i
    Commands::PublicGamesHandler.call(@controller, @user, page: page)
    answer_callback
  end

  def handle_settings
    action = @parts[1]
    case action
    when "my_subs"
      page = (@parts[2] || 0).to_i
      Commands::SettingsHandler.show_my_subscriptions(@controller, @user, page: page)
      answer_callback
    when "organizers"
      page = (@parts[2] || 0).to_i
      Commands::SettingsHandler.show_organizers(@controller, @user, page: page)
      answer_callback
    when "subscribe"
      handle_subscribe
    when "unsubscribe"
      handle_unsubscribe
    when "search_subs"
      @controller.send_message(@user.telegram_id, I18n.t("bot.settings.search_prompt", locale: @locale))
      @controller.write_fsm_state(@user.id, step: "search_subscriptions", data: {})
      answer_callback
    when "search_orgs"
      @controller.send_message(@user.telegram_id, I18n.t("bot.settings.search_prompt", locale: @locale))
      @controller.write_fsm_state(@user.id, step: "search_organizers", data: {})
      answer_callback
    when "my_subs_s"
      page = (@parts[2] || 0).to_i
      search_query = @parts[3..].join(":")
      Commands::SettingsHandler.show_search_results(@controller, @user, search_query, :my_subs, page: page)
      answer_callback
    when "orgs_s"
      page = (@parts[2] || 0).to_i
      search_query = @parts[3..].join(":")
      Commands::SettingsHandler.show_search_results(@controller, @user, search_query, :organizers, page: page)
      answer_callback
    when "presets"
      Commands::PresetsHandler.call(@controller, @user)
      answer_callback
    when "back"
      Commands::SettingsHandler.call(@controller, @user)
      answer_callback
    when "locale"
      new_locale = @parts[2]
      @user.update!(locale: new_locale)
      answer_callback(I18n.t("bot.locale_updated", locale: new_locale.to_sym))
    when "timezone"
      Commands::SettingsHandler.show_timezone_picker(@controller, @user)
      answer_callback
    when "set_tz"
      new_tz = @parts[2..].join(":")
      if User::SUPPORTED_TIME_ZONES.key?(new_tz)
        @user.update!(time_zone: new_tz)
        answer_callback(I18n.t("bot.timezone_updated", locale: @locale))
      else
        answer_callback
      end
    end
  end

  def handle_preset
    action = @parts[1]
    case action
    when "select"          then handle_preset_select
    when "new_game"        then Commands::NewGameHandler.start_fresh(@controller, @user); answer_callback
    when "no_change"       then handle_preset_no_change
    when "change"          then handle_preset_change
    when "edit_field"      then handle_preset_edit_field
    when "edit_done"       then handle_preset_edit_done
    when "view"            then Commands::PresetsHandler.show_preset(@controller, @user, @parts[2].to_i); answer_callback
    when "manage_edit"     then handle_preset_manage_edit
    when "manage_list"     then Commands::PresetsHandler.call(@controller, @user); answer_callback
    when "delete_confirm"  then handle_preset_delete_confirm
    when "delete_yes"      then handle_preset_delete_yes
    when "delete_no"       then Commands::PresetsHandler.call(@controller, @user); answer_callback
    when "save_yes"        then handle_preset_save_yes
    when "save_no"         then @controller.clear_fsm_state(@user.id); answer_callback
    when "replace"         then handle_preset_replace
    when "invitees_yes"    then handle_preset_invitees_yes
    when "invitees_no"     then @controller.clear_fsm_state(@user.id); answer_callback
    when "remove_invitee"  then handle_preset_remove_invitee
    when "add_invitee"     then handle_preset_add_invitee
    else answer_callback
    end
  end

  def handle_filter
    filter_type = @parts[1]
    filter_val  = @parts[2]
    Commands::PublicGamesHandler.call(@controller, @user, filters: { filter_type.to_sym => filter_val })
    answer_callback
  end

  def handle_calendar
    result = TelegramCalendar.process(@parts, locale: @locale, time_zone: @user.tz)
    return answer_callback if result.nil?

    cb_message = @controller.payload&.dig("message")
    return answer_callback unless cb_message

    chat_id    = cb_message.dig("chat", "id")
    message_id = cb_message["message_id"]

    if result[:datetime]
      complete_calendar_selection(result[:datetime], chat_id, message_id)
    else
      @controller.edit_message_text(chat_id, message_id, result[:text],
                                    reply_markup: result[:keyboard])
    end

    answer_callback
  end

  private

  def answer_callback(text = nil)
    @controller.answer_callback(text)
  end

  def complete_calendar_selection(datetime, chat_id, message_id)
    state = @controller.read_fsm_state(@user.id)
    return unless state && %w[datetime relaunch_datetime preset_datetime].include?(state[:step])

    unless datetime > Game::MIN_HOURS_BEFORE_GAME.hours.from_now
      @controller.edit_message_text(chat_id, message_id,
                                    I18n.t("bot.datetime_too_soon", hours: Game::MIN_HOURS_BEFORE_GAME, locale: @locale))
      return
    end

    formatted = datetime.in_time_zone(@user.tz).strftime("%d.%m.%Y %H:%M")
    @controller.edit_message_text(chat_id, message_id, "✅ #{formatted}")

    case state[:step]
    when "datetime"
      data = state[:data].merge(scheduled_at: datetime.iso8601)
      @controller.write_fsm_state(@user.id, step: "location", data: data)

      existing_locations = Location.where(organizer_id: @user.id)
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.select_location", locale: @locale),
        reply_markup: TelegramMessageBuilder.location_keyboard(existing_locations, locale: @locale)
      )
    when "relaunch_datetime"
      data = state[:data].merge(scheduled_at: datetime.iso8601)
      @controller.clear_fsm_state(@user.id)
      GameCreator.finish(@user, @controller, data)
    when "preset_datetime"
      data = state[:data].merge(scheduled_at: datetime.iso8601)
      @controller.clear_fsm_state(@user.id)
      game = GameCreator.finish(@user, @controller, data)

      if game
        preset_id = data[:preset_id] || data["preset_id"]
        preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id) if preset_id

        if preset&.game_preset_invitees&.any?
          invitee_names = preset.game_preset_invitees.map { |i| "@#{i.username}" }.join(", ")
          fsm_data = data.merge(created_game_id: game.id)
          @controller.write_fsm_state(@user.id, step: "preset_confirm_invitees", data: fsm_data)
          @controller.send_message(
            @user.telegram_id,
            I18n.t("bot.presets.confirm_invitees", list: invitee_names, locale: @locale),
            reply_markup: TelegramMessageBuilder.preset_confirm_invitees_keyboard(locale: @locale)
          )
        end
      end
    end
  end

  def handle_subscribe
    organizer_id = @parts[2].to_i
    organizer = User.find_by(id: organizer_id)
    return answer_callback unless organizer

    Subscription.create!(subscriber: @user, organizer: organizer)
    answer_callback(I18n.t("bot.subscribed_successfully", locale: @locale))
    Commands::SettingsHandler.show_organizers(@controller, @user, page: 0)
  rescue ActiveRecord::RecordInvalid
    answer_callback
  end

  def handle_unsubscribe
    organizer_id = @parts[2].to_i
    @user.subscriptions.find_by(organizer_id: organizer_id)&.destroy!
    answer_callback(I18n.t("bot.unsubscribed_successfully", locale: @locale))
    Commands::SettingsHandler.show_my_subscriptions(@controller, @user, page: 0)
  end

  # --- Preset handlers ---

  def handle_preset_select
    preset = @user.game_presets.includes(:location, :game_preset_invitees).find_by(id: @parts[2].to_i)
    return answer_callback unless preset

    data = PresetService.build_game_data(preset).merge(preset_id: preset.id)
    @controller.write_fsm_state(@user.id, step: "preset_summary", data: data)

    summary = PresetService.preset_summary(preset, locale: @locale)
    @controller.send_message(
      @user.telegram_id,
      "#{I18n.t("bot.presets.summary_title", locale: @locale)}\n\n#{summary}\n#{I18n.t("bot.presets.change_anything", locale: @locale)}",
      reply_markup: TelegramMessageBuilder.preset_change_keyboard(locale: @locale)
    )
    answer_callback
  end

  def handle_preset_no_change
    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    @controller.write_fsm_state(@user.id, step: "preset_datetime", data: state[:data])
    cal = TelegramCalendar.start(locale: @locale, time_zone: @user.tz)
    @controller.send_message(@user.telegram_id, cal[:text], reply_markup: cal[:keyboard])
    answer_callback
  end

  def handle_preset_change
    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    preset_id = state[:data][:preset_id] || state[:data]["preset_id"]
    @controller.write_fsm_state(@user.id, step: "preset_edit_menu", data: state[:data])
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.select_field", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: @locale)
    )
    answer_callback
  end

  def handle_preset_edit_field
    preset_id = @parts[2].to_i
    field     = @parts[3]
    state     = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    manage_mode = state[:step]&.start_with?("preset_manage")
    step_prefix = manage_mode ? "preset_manage_edit" : "preset_edit"

    case field
    when "sport_type"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_sport_type", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.select_sport_type", locale: @locale),
        reply_markup: TelegramMessageBuilder.sport_type_keyboard(locale: @locale)
      )
    when "event_type"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_event_type", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.select_event_type", locale: @locale),
        reply_markup: TelegramMessageBuilder.event_type_keyboard(locale: @locale)
      )
    when "location"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_location", data: state[:data].merge(editing_preset_id: preset_id))
      existing_locations = Location.where(organizer_id: @user.id)
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.select_location", locale: @locale),
        reply_markup: TelegramMessageBuilder.location_keyboard(existing_locations, locale: @locale)
      )
    when "max_participants"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_max", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(@user.telegram_id, I18n.t("bot.enter_max_participants", locale: @locale))
    when "min_participants"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_min", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(@user.telegram_id, I18n.t("bot.enter_min_participants", max: state[:data][:max_participants] || state[:data]["max_participants"], locale: @locale))
    when "visibility"
      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_visibility", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.select_visibility", locale: @locale),
        reply_markup: TelegramMessageBuilder.visibility_keyboard(locale: @locale)
      )
    when "invitees"
      preset = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id)
      return answer_callback unless preset

      @controller.write_fsm_state(@user.id, step: "#{step_prefix}_invitees", data: state[:data].merge(editing_preset_id: preset_id))
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.presets.field_invitees", locale: @locale),
        reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: @locale)
      )
    end
    answer_callback
  end

  def handle_preset_edit_done
    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    if state[:step]&.start_with?("preset_manage")
      # In manage mode — save changes to preset record and return to list
      preset_id = state[:data][:editing_preset_id] || state[:data]["editing_preset_id"] ||
                  state[:data][:preset_id] || state[:data]["preset_id"]
      preset = @user.game_presets.find_by(id: preset_id)

      if preset
        preset.update!(
          sport_type:       state[:data][:sport_type] || state[:data]["sport_type"],
          event_type:       state[:data][:event_type] || state[:data]["event_type"],
          location_id:      state[:data][:location_id] || state[:data]["location_id"],
          max_participants: (state[:data][:max_participants] || state[:data]["max_participants"]).to_i,
          min_participants: (state[:data][:min_participants] || state[:data]["min_participants"]).to_i,
          visibility:       state[:data][:visibility] || state[:data]["visibility"]
        )
        @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_updated", locale: @locale))
      end

      @controller.clear_fsm_state(@user.id)
      Commands::PresetsHandler.call(@controller, @user)
    else
      # In game-creation mode — return to preset summary with change keyboard
      preset_id = state[:data][:preset_id] || state[:data]["preset_id"]
      preset = GamePreset.includes(:location, :game_preset_invitees).find_by(id: preset_id)
      if preset
        summary = PresetService.preset_summary(preset, locale: @locale)
        @controller.send_message(
          @user.telegram_id,
          "#{I18n.t("bot.presets.summary_title", locale: @locale)}\n\n#{summary}\n#{I18n.t("bot.presets.change_anything", locale: @locale)}",
          reply_markup: TelegramMessageBuilder.preset_change_keyboard(locale: @locale)
        )
      end
      @controller.write_fsm_state(@user.id, step: "preset_summary", data: state[:data])
    end
    answer_callback
  end

  def handle_preset_manage_edit
    preset_id = @parts[2].to_i
    preset = @user.game_presets.includes(:location, :game_preset_invitees).find_by(id: preset_id)
    return answer_callback unless preset

    data = PresetService.build_game_data(preset).merge(editing_preset_id: preset.id, preset_id: preset.id)
    @controller.write_fsm_state(@user.id, step: "preset_manage_edit_menu", data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.select_field", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset.id, locale: @locale)
    )
    answer_callback
  end

  def handle_preset_delete_confirm
    preset_id = @parts[2].to_i
    preset = @user.game_presets.find_by(id: preset_id)
    return answer_callback unless preset

    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.delete_confirm", name: preset.name, locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_delete_confirm_keyboard(preset.id, locale: @locale)
    )
    answer_callback
  end

  def handle_preset_delete_yes
    preset_id = @parts[2].to_i
    preset = @user.game_presets.find_by(id: preset_id)

    if preset
      PresetService.delete(preset)
      @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_deleted", locale: @locale))
    end

    Commands::PresetsHandler.call(@controller, @user)
    answer_callback
  end

  def handle_preset_save_yes
    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    data = state[:data]
    existing_presets = @user.game_presets.to_a

    if existing_presets.size < GamePreset::MAX_PRESETS_PER_ORGANIZER
      preset = PresetService.create_from_game_data(organizer: @user, game_data: data, locale: @locale)
      @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_saved", name: preset.name, locale: @locale))
      @controller.clear_fsm_state(@user.id)
    else
      @controller.write_fsm_state(@user.id, step: "save_preset_replace", data: data)
      @controller.send_message(
        @user.telegram_id,
        I18n.t("bot.presets.preset_limit_replace", locale: @locale),
        reply_markup: TelegramMessageBuilder.preset_replace_keyboard(existing_presets, locale: @locale)
      )
    end
    answer_callback
  end

  def handle_preset_replace
    old_preset_id = @parts[2].to_i
    old_preset = @user.game_presets.find_by(id: old_preset_id)
    return answer_callback unless old_preset

    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    data = state[:data]
    new_preset = PresetService.replace(old_preset: old_preset, organizer: @user, game_data: data, locale: @locale)
    @controller.send_message(@user.telegram_id, I18n.t("bot.presets.preset_replaced", locale: @locale))
    @controller.clear_fsm_state(@user.id)
    answer_callback
  end

  def handle_preset_invitees_yes
    state = @controller.read_fsm_state(@user.id)
    return answer_callback unless state

    data = state[:data]
    game_id   = data[:created_game_id] || data["created_game_id"]
    preset_id = data[:preset_id] || data["preset_id"]
    game      = Game.find_by(id: game_id)
    preset    = GamePreset.includes(:game_preset_invitees).find_by(id: preset_id)

    if game && preset
      preset.game_preset_invitees.each do |inv|
        invitee = User.find_by(username: inv.username)
        if invitee
          InvitationService.create(game: game, inviter: @user, invitee: invitee)
        else
          InvitationService.create_for_unknown_user(game: game, inviter: @user, invitee_username: inv.username)
        end
      end
    end

    @controller.clear_fsm_state(@user.id)
    answer_callback
  end

  def handle_preset_remove_invitee
    preset_id  = @parts[2].to_i
    invitee_id = @parts[3].to_i
    preset = @user.game_presets.includes(:game_preset_invitees).find_by(id: preset_id)
    return answer_callback unless preset

    invitee = preset.game_preset_invitees.find_by(id: invitee_id)
    if invitee
      username = invitee.username
      invitee.destroy!
      @controller.send_message(@user.telegram_id, I18n.t("bot.presets.invitee_removed", username: username, locale: @locale))
    end

    preset.reload
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.field_invitees", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_invitees_edit_keyboard(preset, locale: @locale)
    )
    answer_callback
  end

  def handle_preset_add_invitee
    preset_id = @parts[2].to_i
    state = @controller.read_fsm_state(@user.id)
    data = state ? state[:data] : {}

    @controller.write_fsm_state(@user.id, step: "preset_add_invitee", data: data.merge(editing_preset_id: preset_id))
    @controller.send_message(@user.telegram_id, I18n.t("bot.presets.add_invitee_prompt", locale: @locale))
    answer_callback
  end

  def handle_preset_fsm_callback(state, field, value)
    preset_id = state[:data][:editing_preset_id] || state[:data]["editing_preset_id"]
    manage_mode = state[:step]&.include?("manage")

    case field
    when "sport_type"
      new_data = state[:data].merge(sport_type: value)
      PresetService.update_field(GamePreset.find(preset_id), :sport_type, value) if manage_mode && preset_id
      return_to_edit_menu(new_data, preset_id, manage_mode)
    when "event_type"
      new_data = state[:data].merge(event_type: value)
      PresetService.update_field(GamePreset.find(preset_id), :event_type, value) if manage_mode && preset_id
      return_to_edit_menu(new_data, preset_id, manage_mode)
    when "location_id"
      if value == "new"
        step = manage_mode ? "preset_manage_edit_location_name" : "preset_edit_location_name"
        @controller.write_fsm_state(@user.id, step: step, data: state[:data])
        @controller.send_message(@user.telegram_id, I18n.t("bot.enter_location_name", locale: @locale))
      else
        new_data = state[:data].merge(location_id: value.to_i)
        PresetService.update_field(GamePreset.find(preset_id), :location_id, value.to_i) if manage_mode && preset_id
        return_to_edit_menu(new_data, preset_id, manage_mode)
      end
    when "visibility"
      new_data = state[:data].merge(visibility: value)
      PresetService.update_field(GamePreset.find(preset_id), :visibility, value) if manage_mode && preset_id
      return_to_edit_menu(new_data, preset_id, manage_mode)
    end
  end

  def return_to_edit_menu(data, preset_id, manage_mode)
    step = manage_mode ? "preset_manage_edit_menu" : "preset_edit_menu"
    @controller.write_fsm_state(@user.id, step: step, data: data)
    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.presets.select_field", locale: @locale),
      reply_markup: TelegramMessageBuilder.preset_edit_menu_keyboard(preset_id, locale: @locale)
    )
  end
end
