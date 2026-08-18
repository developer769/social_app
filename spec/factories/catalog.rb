FactoryBot.define do
  factory :product do
    workspace
    sequence(:name) { |n| "Chocolate Truffle Cake #{n}" }
    category { "Cakes" }
    price_minor { 154_900 }
    currency { "INR" }
  end

  factory :service do
    workspace
    sequence(:name) { |n| "Custom Birthday Cake Service #{n}" }
    category { "Custom Cakes" }
    starting_price_minor { 199_900 }
    currency { "INR" }
    duration_min_days { 2 }
    duration_max_days { 3 }
  end
end
