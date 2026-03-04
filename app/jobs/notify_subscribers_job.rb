class NotifySubscribersJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.active?

    subscribers = User.joins(:subscriptions)
                      .where(subscriptions: { organizer_id: game.organizer_id })

    subscribers.find_each do |subscriber|
      if game.public_game?
        NotificationService.notify_new_game(subscriber, game)
      elsif game.private_game? && ever_invited?(subscriber, game.organizer_id)
        NotificationService.notify_new_game(subscriber, game)
      end
    end
  end

  private

  def ever_invited?(user, organizer_id)
    Invitation.joins(:game)
              .where(invitee_id: user.id, games: { organizer_id: organizer_id })
              .exists?
  end
end
