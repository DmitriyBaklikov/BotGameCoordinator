class CallbackRouter
  HANDLERS = {
    "menu"         => :handle_menu,
    "fsm"          => :handle_fsm,
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

    updated_card     = TelegramMessageBuilder.event_card(game.reload, locale: @locale)
    updated_keyboard = TelegramMessageBuilder.vote_keyboard(game, locale: @locale)

    if @controller.callback_query&.message
      msg = @controller.callback_query.message
      @controller.edit_message_text(msg.chat.id, msg.message_id, updated_card[:text],
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
    when "subscriptions"
      show_subscriptions
    when "locale"
      new_locale = @parts[2]
      @user.update!(locale: new_locale)
      answer_callback(I18n.t("bot.locale_updated", locale: new_locale.to_sym))
    end
  end

  def handle_filter
    filter_type = @parts[1]
    filter_val  = @parts[2]
    Commands::PublicGamesHandler.call(@controller, @user, filters: { filter_type.to_sym => filter_val })
    answer_callback
  end

  private

  def answer_callback(text = nil)
    @controller.answer_callback(text)
  end

  def show_subscriptions
    subscriptions = @user.subscriptions.includes(:organizer)
    organizers    = User.organizers.where.not(id: @user.id).limit(20)

    buttons = organizers.map do |org|
      subscribed = subscriptions.any? { |s| s.organizer_id == org.id }
      label = "#{subscribed ? '✅' : '➕'} #{org.display_name}"
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text:          label,
        callback_data: "settings:toggle_sub:#{org.id}"
      )]
    end

    @controller.send_message(
      @user.telegram_id,
      I18n.t("bot.settings.subscriptions_header", locale: @locale),
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    )
  end
end
