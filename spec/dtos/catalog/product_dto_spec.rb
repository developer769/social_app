require "rails_helper"

RSpec.describe Catalog::ProductDto do
  it "converts a typed price into integer minor units" do
    expect(described_class.new(price: "1549").price_minor).to eq(154_900)
  end

  it "accepts prices typed with separators and symbols, because owners do" do
    expect(described_class.new(price: "1,549").price_minor).to eq(154_900)
    expect(described_class.new(price: "\u20B9 1549.50").price_minor).to eq(154_950)
  end

  it "leaves the price unset when nothing was entered" do
    expect(described_class.new(price: "").price_minor).to be_nil
    expect(described_class.new.price_minor).to be_nil
  end

  it "adds a scheme to a bare product URL" do
    expect(described_class.new(url: "anayabakes.com/cakes").url).to eq("https://anayabakes.com/cakes")
  end

  it "falls back to safe defaults when a status is not recognised" do
    dto = described_class.new(availability_status: "on_the_moon", stock_status: "maybe")

    expect(dto.availability_status).to eq("available")
    expect(dto.stock_status).to eq("in_stock")
  end

  it "casts checkbox values to real booleans" do
    expect(described_class.new(featured: "1").featured).to be(true)
    expect(described_class.new(featured: "0").featured).to be(false)
    expect(described_class.new.featured).to be(false)
  end

  it "is immutable" do
    expect(described_class.new(name: "Chocolate Truffle Cake")).to be_frozen
  end
end
