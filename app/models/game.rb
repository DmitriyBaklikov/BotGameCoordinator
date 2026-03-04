class Game < ApplicationRecord
  ACTIVE_EVENTS_LIMIT = 2
  MIN_HOURS_BEFORE_GAME = 2

  enum sport_type: { basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6 }
  enum event_type: { game: 0, training: 1 }
  enum status:     { draft: 0, active: 1, cancelled: 2, archived: 3 }
  enum visibility: { public_game: 0, private_game: 1 }

  belongs_to :organizer, class_name: "User"
  belongs_to :location

  has_many :game_participants, dependent: :destroy
  has_many :going_participants,   -> { going },   through: :game_participants, source: :user
  has_many :maybe_participants,   -> { maybe },   through: :game_participants, source: :user
  has_many :reserve_participants, -> { reserve }, through: :game_participants, source: :user
  has_many :invitations, dependent: :destroy

  validates :title,            presence: true
  validates :scheduled_at,     presence: true
  validates :max_participants, presence: true, numericality: { only_integer: true, in: 2..100 }
  validates :min_participants, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :sport_type,  presence: true
  validates :event_type,  presence: true
  validates :status,      presence: true
  validates :visibility,  presence: true

  validate :min_not_greater_than_max
  validate :scheduled_at_in_future, on: :create
  validate :organizer_active_event_limit, on: :create

  before_validation :set_title, if: :auto_title?

  scope :active_for_organizer, ->(organizer_id) { active.where(organizer_id: organizer_id) }
  scope :public_active, -> { where(visibility: :public_game, status: :active).where("scheduled_at > ?", Time.current) }
  scope :expiring_soon, -> { active.where(scheduled_at: Time.current..3.hours.from_now) }
  scope :past_active,   -> { active.where("scheduled_at < ?", Time.current) }

  def going_count
    game_participants.going.count
  end

  def maybe_count
    game_participants.maybe.count
  end

  def reserve_count
    game_participants.reserve.count
  end

  def at_capacity?
    going_count >= max_participants
  end

  private

  def auto_title?
    title.blank? && sport_type.present? && event_type.present?
  end

  def set_title
    locale = organizer&.locale || I18n.default_locale
    sport = I18n.t("game.sport_types.#{sport_type}", locale: locale)
    evt   = I18n.t("game.event_types.#{event_type}", locale: locale)
    self.title = "#{sport} (#{evt})"
  end

  def min_not_greater_than_max
    return if min_participants.blank? || max_participants.blank?
    return if min_participants <= max_participants

    errors.add(:min_participants, :greater_than_max)
  end

  def scheduled_at_in_future
    return if scheduled_at.blank?
    return if scheduled_at > MIN_HOURS_BEFORE_GAME.hours.from_now

    errors.add(:scheduled_at, :too_soon)
  end

  def organizer_active_event_limit
    return if organizer_id.blank?
    return if Game.active_for_organizer(organizer_id).count < ACTIVE_EVENTS_LIMIT

    errors.add(:base, :active_event_limit_reached)
  end
end
