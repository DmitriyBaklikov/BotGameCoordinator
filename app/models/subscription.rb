class Subscription < ApplicationRecord
  belongs_to :subscriber, class_name: "User"
  belongs_to :organizer,  class_name: "User"

  validates :subscriber_id, uniqueness: { scope: :organizer_id }
  validate  :cannot_subscribe_to_self

  private

  def cannot_subscribe_to_self
    return unless subscriber_id == organizer_id

    errors.add(:base, :self_subscription)
  end
end
