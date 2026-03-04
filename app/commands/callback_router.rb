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
    GameCreator.handle_callback(@user, @controller, @parts[1], @parts[2])
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
    return unless state && %w[datetime relaunch_datetime].include?(state[:step])

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
end
