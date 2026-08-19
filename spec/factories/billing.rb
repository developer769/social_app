FactoryBot.define do
  factory :plan do
    sequence(:code) { |n| "plan_#{n}" }
    name { "Plan" }
    tagline { "A plan" }
    price_minor { 99_900 }
    currency { "INR" }
    interval { "month" }
    trial_days { 14 }
    active { true }

    trait :basic do
      code { "basic" }
      name { "Basic" }
      price_minor { 49_900 }
      position { 1 }
    end

    trait :pro do
      code { "pro" }
      name { "Pro" }
      price_minor { 99_900 }
      recommended { true }
      position { 2 }
    end

    trait :business do
      code { "business" }
      name { "Business" }
      price_minor { 199_900 }
      position { 3 }
    end

    trait :with_entitlements do
      after(:create) do |plan|
        create(:plan_entitlement, plan: plan, key: "social_accounts", limit_value: 3,
               display_label: "3 social accounts")
        create(:plan_entitlement, plan: plan, key: "posts_per_month", limit_value: nil,
               display_label: "Unlimited posts")
      end
    end
  end

  factory :plan_entitlement do
    plan
    key { "social_accounts" }
    limit_value { 3 }
    display_label { "3 social accounts" }
  end

  factory :social_health_score do
    workspace
    score { 70 }
    rating { "good" }
    coverage_percentage { 60 }
    components { [] }
    computed_at { Time.current }
  end
end
