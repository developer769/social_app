FactoryBot.define do
  factory :staff_user do
    sequence(:email) { |n| "staff#{n}@prachar.test" }
    name { "Prachar Studio" }
    password { "correct-horse-battery-staple" }
  end
end
