class ReservePromotionJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.active?
    return unless game.game_participants.going.count < game.max_participants

    reserve = game.game_participants.reserve.order(:created_at).first
    return unless reserve
    return if reserve.notified_reserve?

    reserve.update!(notified_reserve: true)
    NotificationService.notify_reserve_promotion(reserve.user, game)
  end
end
