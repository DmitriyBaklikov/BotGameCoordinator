FactoryBot.define do
  factory :subscription do
    association :subscriber, factory: :user
    association :organizer, factory: [:user, :organizer]
  end
end
