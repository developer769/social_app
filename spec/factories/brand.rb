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
