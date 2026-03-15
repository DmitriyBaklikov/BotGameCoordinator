class Invitation < ApplicationRecord
  enum status: { pending: 0, accepted: 1, declined: 2 }

  belongs_to :game
  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User", optional: true

  validates :game_id, uniqueness: { scope: :invitee_id }, if: -> { invitee_id.present? }
  validates :token, uniqueness: true
  validates :status, presence: true

  before_create :generate_token

  def valid_for_deep_link?
    pending? && game.active? && game.scheduled_at > Time.current
  end

  private

  def generate_token
    self.token ||= SecureRandom.uuid
  end
end
