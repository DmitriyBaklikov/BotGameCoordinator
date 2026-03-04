FactoryBot.define do
  factory :user_session do
    association :user
    state { nil }
    data { {} }
  end
end
