FactoryBot.define do
  factory :game_preset do
    association :organizer, factory: [:user, :organizer]
    association :location
    name { "Basketball (Game) / Test Location" }
    sport_type { :basketball }
    event_type { :game }
    max_participants { 10 }
    min_participants { 4 }
    visibility { :public_game }
  end
end
