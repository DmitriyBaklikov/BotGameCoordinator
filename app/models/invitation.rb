class Invitation < ApplicationRecord
  enum status: { pending: 0, accepted: 1, declined: 2 }

  belongs_to :game
  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User"

  validates :game_id, uniqueness: { scope: :invitee_id }
  validates :status, presence: true
end
