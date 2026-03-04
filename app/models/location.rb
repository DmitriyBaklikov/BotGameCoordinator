class Location < ApplicationRecord
  belongs_to :organizer, class_name: "User"

  has_many :games, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organizer_id, case_sensitive: false }
end
