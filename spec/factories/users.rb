FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "owner#{n}@anayabakes.test" }
    name { "Anaya Sharma" }
    password { "correct-horse-battery" }
    timezone { "Asia/Kolkata" }

    trait :confirmed do
      confirmed_at { Time.current }
    end
  end
end
