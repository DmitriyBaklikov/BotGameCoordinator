FactoryBot.define do
  factory :game do
    association :organizer, factory: [:user, :organizer]
    association :location
    sport_type { :basketball }
    event_type { :game }
    title { "Basketball (Game)" }
    scheduled_at { 2.days.from_now }
    max_participants { 10 }
    min_participants { 4 }
    status { :active }
    visibility { :public_game }

    trait :draft do
      status { :draft }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :archived do
      status { :archived }
    end

    trait :private_game do
      visibility { :private_game }
    end

    trait :expiring_soon do
      scheduled_at { 2.hours.from_now }
    end

    trait :past do
      scheduled_at { 1.hour.ago }
    end
  end
end
