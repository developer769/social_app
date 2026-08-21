FactoryBot.define do
  factory :brand_profile do
    workspace
    category { "Bakery" }
    business_type { "small_business" }
    city { "Delhi, India" }
  end

  factory :brand_goal do
    workspace
    goal { "increase_sales" }
  end

  factory :brand_tone do
    workspace
    tone { "friendly" }
  end
end

FactoryBot.define do
  factory :posting_preference do
    workspace
    posts_per_week { 3 }
    preferred_days { [ 1, 3, 5 ] }
    preferred_time { "10:00" }
    caption_style { "balanced" }
    hashtag_style { "balanced" }
    emoji_level { "minimal" }
  end
end
