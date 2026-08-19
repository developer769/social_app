require "rails_helper"

RSpec.describe "Plan entitlement labels" do
  before { load Rails.root.join("db/seeds/plans.rb") }

  # The plan screen sits behind a "Start trial" button. It is the worst place in
  # the product to describe a capability nothing delivers, and it did: it sold
  # "Unlimited AI generations" while no generation provider existed anywhere.
  it "never sells AI while no generation provider is registered" do
    skip "a real generation provider is registered" if FeatureAvailability.creative_generation_live?

    offenders = PlanEntitlement.all.select { |e| e.display_label.match?(/\bAI\b/i) }

    expect(offenders.map(&:display_label)).to be_empty,
      "these plan labels claim AI with no provider behind it: #{offenders.map(&:display_label).inspect}"
  end

  it "reports generation as not yet live" do
    expect(FeatureAvailability.live?("ai_generations_per_month")).to be(false)
  end

  it "treats an entitlement with no provider dependency as available" do
    expect(FeatureAvailability.live?("social_accounts")).to be(true)
  end

  it "states a real number for every plan rather than an unbounded promise" do
    PlanEntitlement.where(key: "ai_generations_per_month").each do |entitlement|
      expect(entitlement.limit_value).to be_present,
        "#{entitlement.display_label} promises unlimited generation, which nothing can honour"
    end
  end
end
