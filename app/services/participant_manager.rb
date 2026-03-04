class ParticipantManager
  def self.vote(game:, user:, vote:)
    ActiveRecord::Base.transaction do
      participant = GameParticipant.find_or_initialize_by(game: game, user: user)
      old_status  = participant.status&.to_sym

      new_status = resolve_status(game, participant, vote)
      participant.status = new_status
      participant.save!

      spot_freed = old_status == :going && new_status != :going

      ReservePromotionJob.perform_later(game.id) if spot_freed

      { status: new_status, message: status_message(new_status, user.locale.to_sym) }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[ParticipantManager] vote error: #{e.message}")
    { status: nil, message: nil }
  end

  def self.remove(game:, user:, remover:)
    return unless game.organizer_id == remover.id

    ActiveRecord::Base.transaction do
      participant = game.game_participants.find_by(user: user)
      return unless participant

      was_going = participant.going?
      participant.destroy!

      NotificationService.notify_removal(user, game)
      ReservePromotionJob.perform_later(game.id) if was_going
    end
  end

  def self.confirm_reserve(game_id:, user:)
    game = Game.find_by(id: game_id)
    return unless game&.active?

    ActiveRecord::Base.transaction do
      participant = game.game_participants.find_by(user: user)
      return unless participant&.reserve?

      if game.going_count < game.max_participants
        participant.update!(status: :going)
      end
    end
  end

  class << self
    private

    def resolve_status(game, participant, vote)
      case vote
      when :going
        if !participant.going? && game.going_count >= game.max_participants
          :reserve
        else
          :going
        end
      when :maybe
        :maybe
      when :not_going
        :not_going
      end
    end

    def status_message(status, locale)
      key = case status
            when :going    then "bot.voted_going"
            when :maybe    then "bot.voted_maybe"
            when :not_going then "bot.voted_not_going"
            when :reserve  then "bot.added_to_reserve"
            end
      I18n.t(key, locale: locale) if key
    end
  end
end
