FactoryBot.define do
  factory :invitation do
    association :game
    association :inviter, factory: [:user, :organizer]
    association :invitee, factory: :user
    status { :pending }

    trait :accepted do
      status { :accepted }
    end

    trait :declined do
      status { :declined }
    end
  end
end
