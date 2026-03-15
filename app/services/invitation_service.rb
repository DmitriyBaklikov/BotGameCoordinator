class InvitationService
  def self.create(game:, inviter:, invitee:)
    return { error: :already_invited } if Invitation.exists?(game: game, invitee: invitee)
    return { error: :already_participant } if GameParticipant.exists?(game: game, user: invitee)

    invitation = Invitation.create!(
      game:    game,
      inviter: inviter,
      invitee: invitee,
      status:  :pending
    )

    SendInvitationJob.perform_later(game.id, inviter.id, invitee.id)
    { invitation: invitation }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def self.create_for_unknown_user(game:, inviter:, invitee_username:)
    if Invitation.exists?(game: game, invitee_username: invitee_username, invitee_id: nil)
      return { error: :already_invited }
    end

    invitation = Invitation.create!(
      game:             game,
      inviter:          inviter,
      invitee_username: invitee_username,
      status:           :pending
    )

    { invitation: invitation }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  def self.accept(invitation_id, user, controller)
    invitation = Invitation.find_by(id: invitation_id, invitee: user)
    return unless invitation&.pending?

    invitation.update!(status: :accepted)

    result = ParticipantManager.vote(game: invitation.game, user: user, vote: :going)
    locale = user.locale.to_sym
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.invitation_accepted", title: invitation.game.title, locale: locale)
    )
  end

  def self.decline(invitation_id, user, controller)
    invitation = Invitation.find_by(id: invitation_id, invitee: user)
    return unless invitation&.pending?

    invitation.update!(status: :declined)

    organizer = invitation.inviter
    locale    = organizer.locale.to_sym
    NotificationService.notify_invite_declined(organizer, user, invitation.game)

    locale = user.locale.to_sym
    controller.send_message(
      user.telegram_id,
      I18n.t("bot.invitation_declined", title: invitation.game.title, locale: locale)
    )
  end
end
