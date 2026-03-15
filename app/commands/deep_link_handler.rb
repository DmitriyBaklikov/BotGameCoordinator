class DeepLinkHandler
  def self.handle_invite(controller, user, payload)
    token      = payload.delete_prefix("invite_")
    invitation = Invitation.find_by(token: token)
    locale     = user.locale.to_sym

    unless invitation
      controller.send_message(user.telegram_id, I18n.t("bot.deep_link_invalid", locale: locale))
      return
    end

    unless invitation.pending?
      controller.send_message(user.telegram_id, I18n.t("bot.deep_link_already_used", locale: locale))
      return
    end

    game = invitation.game
    unless game.active? && game.scheduled_at > Time.current
      controller.send_message(user.telegram_id, I18n.t("bot.deep_link_game_unavailable", locale: locale))
      return
    end

    # For known-user invitations, verify the clicker is the intended recipient
    if invitation.invitee_id.present? && invitation.invitee_id != user.id
      controller.send_message(user.telegram_id, I18n.t("bot.deep_link_invalid", locale: locale))
      return
    end

    # Backfill invitee_id for unknown-user invitations
    if invitation.invitee_id.nil?
      invitation.update!(invitee: user)
    end

    invitation.update!(status: :accepted)

    result = ParticipantManager.vote(game: game, user: user, vote: :going)

    message = if result[:status] == :reserve
                I18n.t("bot.deep_link_reserve", title: game.title, locale: locale)
              else
                I18n.t("bot.deep_link_joined", title: game.title, locale: locale)
              end

    controller.send_message(user.telegram_id, message)
  end
end
