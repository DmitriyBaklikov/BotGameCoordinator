class CheckGameThresholdsJob < ApplicationJob
  queue_as :default

  def perform
    Game.expiring_soon.find_each do |game|
      going_count = game.game_participants.going.count
      next if going_count >= game.min_participants

      ActiveRecord::Base.transaction do
        game.update!(status: :cancelled)
        NotificationService.notify_cancellation(game)
      end
    rescue StandardError => e
      Rails.logger.error("[CheckGameThresholdsJob] Error processing game #{game.id}: #{e.message}")
    end
  end
end
