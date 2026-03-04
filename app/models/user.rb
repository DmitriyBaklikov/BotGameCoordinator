class User < ApplicationRecord
  # Maps UTC offset labels to Rails timezone identifiers.
  # Default is UTC+03:00 (Moscow).
  SUPPORTED_TIME_ZONES = {
    "UTC-12:00" => "International Date Line West",
    "UTC-11:00" => "American Samoa",
    "UTC-10:00" => "Hawaii",
    "UTC-09:00" => "Alaska",
    "UTC-08:00" => "Pacific Time (US & Canada)",
    "UTC-07:00" => "Arizona",
    "UTC-06:00" => "Central America",
    "UTC-05:00" => "Bogota",
    "UTC-04:00" => "Atlantic Time (Canada)",
    "UTC-03:30" => "Newfoundland",
    "UTC-03:00" => "Brasilia",
    "UTC-02:00" => "Greenland",
    "UTC-01:00" => "Azores",
    "UTC+00:00" => "London",
    "UTC+01:00" => "Amsterdam",
    "UTC+02:00" => "Athens",
    "UTC+03:00" => "Moscow",
    "UTC+03:30" => "Tehran",
    "UTC+04:00" => "Abu Dhabi",
    "UTC+04:30" => "Kabul",
    "UTC+05:00" => "Ekaterinburg",
    "UTC+05:30" => "Chennai",
    "UTC+05:45" => "Kathmandu",
    "UTC+06:00" => "Dhaka",
    "UTC+06:30" => "Rangoon",
    "UTC+07:00" => "Bangkok",
    "UTC+08:00" => "Beijing",
    "UTC+09:00" => "Tokyo",
    "UTC+09:30" => "Adelaide",
    "UTC+10:00" => "Brisbane",
    "UTC+11:00" => "Magadan",
    "UTC+12:00" => "Auckland",
    "UTC+13:00" => "Nuku'alofa"
  }.freeze

  DEFAULT_TIME_ZONE = "UTC+03:00"

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
  validates :time_zone, presence: true, inclusion: { in: SUPPORTED_TIME_ZONES.keys }

  scope :organizers, -> { where(role: :organizer) }

  def self.find_or_create_from_telegram(tg_user)
    find_or_create_by!(telegram_id: tg_user.id) do |u|
      u.username   = tg_user.username
      u.first_name = tg_user.first_name
      u.last_name  = tg_user.last_name
      u.locale     = tg_user.language_code&.slice(0, 2)&.then { |l| %w[en ru].include?(l) ? l : "en" } || "en"
      u.role       = :participant
      u.time_zone  = DEFAULT_TIME_ZONE
    end
  end

  def display_name
    name = [first_name, last_name].compact.join(" ").presence || "User ##{telegram_id}"
    username.present? ? "#{name} (@#{username})" : name
  end

  # Returns the ActiveSupport::TimeZone for this user.
  def tz
    rails_tz_name = SUPPORTED_TIME_ZONES[time_zone] || SUPPORTED_TIME_ZONES[DEFAULT_TIME_ZONE]
    ActiveSupport::TimeZone[rails_tz_name]
  end
end
