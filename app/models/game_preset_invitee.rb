class GamePresetInvitee < ApplicationRecord
  belongs_to :game_preset
  belongs_to :user, optional: true
end
