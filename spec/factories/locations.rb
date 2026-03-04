FactoryBot.define do
  factory :location do
    association :organizer, factory: [:user, :organizer]
    sequence(:name) { |n| "Location #{n}" }
    address { Faker::Address.full_address }
  end
end
