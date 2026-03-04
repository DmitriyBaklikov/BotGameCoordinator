class UserSession < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true

  def self.for_user(user_id)
    find_or_initialize_by(user_id: user_id)
  end

  def advance!(new_state, extra_data = {})
    self.state = new_state
    self.data  = (data || {}).merge(extra_data.stringify_keys)
    save!
  end

  def clear!
    update!(state: nil, data: {})
  end
end
