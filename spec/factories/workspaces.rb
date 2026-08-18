FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Anaya Bakes #{n}" }
    association :owner_user, factory: :user

    trait :onboarded do
      onboarding_step { "completed" }
      onboarding_completed_at { Time.current }
    end
  end
end
