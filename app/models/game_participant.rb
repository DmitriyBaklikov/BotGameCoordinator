class GameParticipant < ApplicationRecord
  enum status: { going: 0, maybe: 1, not_going: 2, reserve: 3 }

  belongs_to :game
  belongs_to :user

  validates :game_id, uniqueness: { scope: :user_id }

  scope :going,   -> { where(status: :going) }
  scope :reserve, -> { where(status: :reserve) }
  scope :maybe,   -> { where(status: :maybe) }
  scope :not_going, -> { where(status: :not_going) }
  scope :active_players, -> { where(status: %i[going maybe reserve]) }
end
