require "rails_helper"

RSpec.describe OnboardingFlow do
  it "defines the six steps the specification requires, in order" do
    expect(described_class.keys).to eq(
      %w[business_setup catalog connections analysis health plan]
    )
  end

  it "walks forwards and backwards through the steps" do
    expect(described_class.next_key("business_setup")).to eq("catalog")
    expect(described_class.previous_key("catalog")).to eq("business_setup")
  end

  it "completes after the final step" do
    expect(described_class.next_key("plan")).to eq("completed")
  end

  it "has no step before the first" do
    expect(described_class.previous_key("business_setup")).to be_nil
  end

  describe ".furthest" do
    it "never moves progress backwards when an earlier step is revisited" do
      expect(described_class.furthest("connections", "business_setup")).to eq("connections")
    end

    it "moves progress forwards" do
      expect(described_class.furthest("business_setup", "catalog")).to eq("catalog")
    end

    it "keeps a completed onboarding completed" do
      expect(described_class.furthest("completed", "business_setup")).to eq("completed")
    end
  end
end
