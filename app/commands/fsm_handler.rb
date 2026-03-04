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

    unless invitee
      controller.send_message(user.telegram_id, I18n.t("bot.user_not_found", username: username, locale: locale))
      return
    end

    SendInvitationJob.perform_later(game.id, user.id, invitee.id)
    controller.send_message(user.telegram_id,
                            I18n.t("bot.invitation_sent", name: invitee.display_name, locale: locale))
    controller.clear_fsm_state(user.id)
  end
end
