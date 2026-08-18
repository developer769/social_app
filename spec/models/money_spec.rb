require "rails_helper"

RSpec.describe Money do
  it "builds from major units without floating point error" do
    expect(described_class.from_major("1549.99", currency: "INR").minor_units).to eq(154_999)
    expect(described_class.from_major("0.10", currency: "INR").minor_units).to eq(10)
  end

  it "respects currencies whose minor unit is not one hundredth" do
    expect(described_class.from_major("500", currency: "JPY").minor_units).to eq(500)
    expect(described_class.from_major("1.5", currency: "KWD").minor_units).to eq(1500)
  end

  it "refuses to compare different currencies" do
    inr = described_class.new(minor_units: 100, currency: "INR")
    usd = described_class.new(minor_units: 100, currency: "USD")

    expect { inr < usd }.to raise_error(ArgumentError, /cannot compare/)
  end

  it "is equal only when both amount and currency match" do
    expect(described_class.new(minor_units: 100, currency: "INR"))
      .to eq(described_class.new(minor_units: 100, currency: "INR"))
    expect(described_class.new(minor_units: 100, currency: "INR"))
      .not_to eq(described_class.new(minor_units: 100, currency: "USD"))
  end
end
