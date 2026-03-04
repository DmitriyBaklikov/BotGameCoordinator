class User < ApplicationRecord
  enum role: { participant: 0, organizer: 1 }

  has_many :games, foreign_key: :organizer_id, dependent: :destroy, inverse_of: :organizer
  has_many :game_participants, dependent: :destroy
  has_many :locations, foreign_key: :organizer_id, dependent: :destroy, inverse_of: :organizer
  has_many :subscriptions, foreign_key: :subscriber_id, dependent: :destroy, inverse_of: :subscriber
  has_many :followed_organizers, through: :subscriptions, source: :organizer
  has_many :invitations, foreign_key: :invitee_id, dependent: :destroy, inverse_of: :invitee
  has_one  :user_session, dependent: :destroy

  validates :telegram_id, presence: true, uniqueness: true
  validates :role, presence: true
  validates :locale, presence: true, inclusion: { in: %w[en ru] }

  scope :organizers, -> { where(role: :organizer) }

  def self.find_or_create_from_telegram(tg_user)
    find_or_create_by!(telegram_id: tg_user.id) do |u|
      u.username   = tg_user.username
      u.first_name = tg_user.first_name
      u.last_name  = tg_user.last_name
      u.locale     = tg_user.language_code&.slice(0, 2)&.then { |l| %w[en ru].include?(l) ? l : "en" } || "en"
      u.role       = :participant
    end
  end

  def display_name
    [first_name, last_name].compact.join(" ").presence || username || "User ##{telegram_id}"
  end
end
