FactoryBot.define do
  factory :user do
    sequence(:telegram_id) { |n| 100_000 + n }
    sequence(:username) { |n| "user#{n}" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { :participant }
    locale { "en" }

    trait :organizer do
      role { :organizer }
    end

    trait :russian do
      locale { "ru" }
    end
  end
end
