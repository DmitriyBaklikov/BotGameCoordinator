class SendInvitationJob < ApplicationJob
  queue_as :default

  def perform(game_id, inviter_id, invitee_id, invitation_id = nil)
    game    = Game.find_by(id: game_id)
    inviter = User.find_by(id: inviter_id)

    return unless game && inviter

    if invitation_id
      handle_unknown_user(game, inviter, invitation_id)
    elsif invitee_id
      handle_known_user(game, inviter, invitee_id)
    end
  end

  private

  def handle_known_user(game, inviter, invitee_id)
    invitee = User.find_by(id: invitee_id)
    return unless invitee

    invitation = Invitation.find_by(game: game, invitee: invitee)
    return unless invitation

    if NotificationService.send_invitation_dm(invitee, game, invitation)
      NotificationService.notify_inviter_dm_sent(inviter, invitee)
    else
      send_deep_link_fallback(inviter, invitee.display_name, invitation)
    end
  end

  def handle_unknown_user(game, inviter, invitation_id)
    invitation = Invitation.find_by(id: invitation_id)
    return unless invitation

    invitee_name = "@#{invitation.invitee_username}"
    send_deep_link_fallback(inviter, invitee_name, invitation)
  end

  def send_deep_link_fallback(inviter, invitee_name, invitation)
    bot_username = Rails.application.config.telegram_bot_username
    link = "https://t.me/#{bot_username}?start=invite_#{invitation.token}"
    NotificationService.notify_inviter_deep_link(inviter, invitee_name, link)
  end
end
