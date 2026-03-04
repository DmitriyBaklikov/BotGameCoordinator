class NotifySubscribersJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.active? && game.public_game?

    subscribers = User.joins(:subscriptions)
                      .where(subscriptions: { organizer_id: game.organizer_id })

    subscribers.find_each do |subscriber|
      NotificationService.notify_new_game(subscriber, game)
    end
  end
end
