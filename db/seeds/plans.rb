# Plans and their entitlements.
#
# Prices come from the Choose Your Plan screen. Annual pricing is offered at ten
# months for twelve, a common and easily explained discount; the screen shows no
# annual pricing, so this is flagged as needing confirmation rather than
# presented as final.
#
# No entitlement may describe a capability the product does not deliver. Image
# generation has no provider yet, so those rows are rendered as not-yet-available
# rather than sold; see FeatureAvailability.
#
# Limits live here as data. Nothing in the application asks "is this Pro?" --
# it asks for an entitlement key (spec 22: centralised entitlement system).
definitions = [
  {
    code: "basic",
    name: "Basic",
    tagline: "For getting started",
    monthly_minor: 49_900,
    position: 1,
    recommended: false,
    entitlements: [
      { key: "social_accounts", limit_value: 1, display_label: "1 social account" },
      { key: "posts_per_month", limit_value: 50, display_label: "50 posts per month" },
      { key: "ai_generations_per_month", limit_value: 30, display_label: "30 image generations per month" },
      { key: "analytics_history_days", limit_value: 30, display_label: "Basic analytics" },
      { key: "team_members", limit_value: 1, display_label: "Just you" },
      { key: "support_level", limit_value: nil, display_label: "Email support" }
    ]
  },
  {
    code: "pro",
    name: "Pro",
    tagline: "For growing businesses",
    monthly_minor: 99_900,
    position: 2,
    recommended: true,
    entitlements: [
      { key: "social_accounts", limit_value: 3, display_label: "3 social accounts" },
      { key: "posts_per_month", limit_value: nil, display_label: "Unlimited posts" },
      { key: "ai_generations_per_month", limit_value: 80, display_label: "80 image generations per month" },
      { key: "analytics_history_days", limit_value: 180, display_label: "Advanced analytics" },
      { key: "team_members", limit_value: 3, display_label: "Up to 3 team members" },
      { key: "support_level", limit_value: nil, display_label: "Email support" }
    ]
  },
  {
    code: "business",
    name: "Business",
    tagline: "For teams running at scale",
    monthly_minor: 199_900,
    position: 3,
    recommended: false,
    entitlements: [
      { key: "social_accounts", limit_value: nil, display_label: "Unlimited accounts" },
      { key: "posts_per_month", limit_value: nil, display_label: "Unlimited posts" },
      { key: "ai_generations_per_month", limit_value: 150, display_label: "150 image generations per month" },
      { key: "analytics_history_days", limit_value: 730, display_label: "Advanced reports" },
      { key: "team_members", limit_value: nil, display_label: "Unlimited team members" },
      { key: "support_level", limit_value: nil, display_label: "Priority support" }
    ]
  }
].freeze

# Twelve months for the price of ten.
annual_multiplier = 10

definitions.each do |definition|
  { "month" => definition[:monthly_minor],
    "year" => definition[:monthly_minor] * annual_multiplier }.each do |interval, price_minor|
    plan = Plan.find_or_initialize_by(code: definition[:code], interval: interval)
    plan.assign_attributes(
      name: definition[:name],
      tagline: definition[:tagline],
      price_minor: price_minor,
      currency: "INR",
      trial_days: 14,
      recommended: definition[:recommended],
      active: true,
      position: definition[:position]
    )
    plan.save!

    definition[:entitlements].each do |entitlement|
      record = PlanEntitlement.find_or_initialize_by(plan: plan, key: entitlement[:key])
      record.assign_attributes(
        limit_value: entitlement[:limit_value],
        display_label: entitlement[:display_label]
      )
      record.save!
    end
  end
end

# Loaded by specs as well as by db:seed, so it stays quiet unless run directly.
puts "Seeded #{Plan.count} plans with #{PlanEntitlement.count} entitlements" unless Rails.env.test?
