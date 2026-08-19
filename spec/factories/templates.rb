FactoryBot.define do
  factory :template do
    sequence(:slug) { |n| "template-#{n}" }
    sequence(:name) { |n| "Template #{n}" }
    description { "A style for showing one product well." }
    media_format { "image" }
    content_category { "product_showcase" }
    aspect_ratio { "4:5" }
    style_tags { %w[warm simple] }
    supported_platforms { %w[instagram facebook] }
    source { "curated" }
    first_seen_at { Time.current }
    active { true }
    draft { false }
    published_at { Time.current }

    trait :video do
      media_format { "video" }
      aspect_ratio { "9:16" }
      duration_seconds { 15 }
    end

    trait :premium do
      premium { true }
    end

    trait :retired do
      retired_at { Time.current }
      active { false }
    end

    trait :trending do
      trend_score { 80 }
      trend_scored_at { Time.current }
    end
  end
end
