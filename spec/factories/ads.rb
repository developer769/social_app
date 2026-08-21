FactoryBot.define do
  factory :ad_campaign do
    workspace
    post { association :post, workspace: workspace }
    social_account { association :social_account, workspace: workspace }
    provider { social_account.provider }
    sequence(:name) { |n| "Diwali hampers boost #{n}" }
    objective { "reach" }
    status { "running" }
    total_budget_minor { 500_000 }
    currency { "INR" }
    starts_on { 7.days.ago.to_date }
  end

  factory :ad_metric do
    ad_campaign
    on_date { Date.current }
    currency { "INR" }
    fetched_at { Time.current }
  end
end

FactoryBot.define do
  factory :ad_outcome do
    ad_campaign
    occurred_on { Date.current }
    orders { 12 }
    revenue_minor { 185_000 }
    currency { "INR" }
  end
end
