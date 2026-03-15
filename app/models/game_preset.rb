class GamePreset < ApplicationRecord
  MAX_PRESETS_PER_ORGANIZER = 5

  enum sport_type: { basketball: 0, football: 1, volleyball: 2, hockey: 3, tennis: 4, badminton: 5, other: 6 }
  enum event_type: { game: 0, training: 1 }
  enum visibility: { public_game: 0, private_game: 1 }

  belongs_to :organizer, class_name: "User"
  belongs_to :location

  has_many :game_preset_invitees, dependent: :destroy

  validates :name, presence: true
  validates :sport_type, presence: true
  validates :event_type, presence: true
  validates :max_participants, presence: true, numericality: { only_integer: true, in: 2..100 }
  validates :min_participants, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :visibility, presence: true

  validate :preset_limit, on: :create

  private

  def preset_limit
    return if organizer_id.blank?
    return if GamePreset.where(organizer_id: organizer_id).count < MAX_PRESETS_PER_ORGANIZER

    errors.add(:base, "Preset limit reached (maximum #{MAX_PRESETS_PER_ORGANIZER})")
  end
end
