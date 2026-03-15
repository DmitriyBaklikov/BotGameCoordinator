FactoryBot.define do
  factory :game_preset_invitee do
    association :game_preset
    association :user
    username { "testuser" }

    trait :unknown_user do
      user { nil }
      username { "unknown_user" }
    end
  end
end
