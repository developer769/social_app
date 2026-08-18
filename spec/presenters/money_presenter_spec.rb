require "rails_helper"

RSpec.describe MoneyPresenter do
  def inr(minor) = described_class.new(Money.new(minor_units: minor, currency: "INR"))
  def usd(minor) = described_class.new(Money.new(minor_units: minor, currency: "USD"))

  describe "Indian digit grouping" do
    it "groups as 2,2,3 rather than 3,3,3" do
      expect(inr(154_900).full).to eq("\u20B91,549")
      expect(inr(14_600_000).full).to eq("\u20B91,46,000")
      expect(inr(23_000_000_000).full).to eq("\u20B923,00,00,000")
    end

    it "uses Western grouping for other currencies" do
      expect(usd(123_456_700).full).to eq("$1,234,567")
    end
  end

  describe "compact form" do
    it "abbreviates in thousands, lakh and crore for INR, as the designs show" do
      expect(inr(4_260_000).compact).to eq("\u20B942.6K")
      expect(inr(14_600_000).compact).to eq("\u20B91.46L")
      expect(inr(23_000_000_000).compact).to eq("\u20B923Cr")
    end

    it "abbreviates in millions and billions for other currencies" do
      expect(usd(123_456_700).compact).to eq("$1.23M")
    end

    it "leaves small amounts unabbreviated" do
      expect(inr(84_900).compact).to eq("\u20B9849")
    end

    it "keeps negative amounts readable" do
      expect(inr(-4_260_000).compact).to eq("-\u20B942.6K")
    end
  end

  it "shows decimals only when the amount has them" do
    expect(inr(154_900).full).to eq("\u20B91,549")
    expect(inr(154_950).full).to eq("\u20B91,549.50")
  end
end
