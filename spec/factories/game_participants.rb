FactoryBot.define do
  factory :game_participant do
    association :game
    association :user
    status { :going }
    invited_by_organizer { false }
    notified_reserve { false }

    trait :maybe do
      status { :maybe }
    end

    trait :not_going do
      status { :not_going }
    end

    trait :reserve do
      status { :reserve }
    end
  end
end
