class ArchiveExpiredGamesJob < ApplicationJob
  queue_as :default

  def perform
    Game.past_active.update_all(status: Game.statuses[:archived])
  end
end
