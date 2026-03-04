class SendInvitationJob < ApplicationJob
  queue_as :default

  def perform(game_id, inviter_id, invitee_id)
    game    = Game.find_by(id: game_id)
    inviter = User.find_by(id: inviter_id)
    invitee = User.find_by(id: invitee_id)

    return unless game && inviter && invitee

    invitation = Invitation.find_or_create_by!(game: game, inviter: inviter, invitee: invitee) do |inv|
      inv.status = :pending
    end

    NotificationService.send_invitation_dm(invitee, game, invitation)
  end
end
