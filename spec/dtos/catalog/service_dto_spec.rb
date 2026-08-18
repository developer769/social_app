require "rails_helper"

RSpec.describe Catalog::ServiceDto do
  it "reads durations as whole positive days" do
    dto = described_class.new(duration_min_days: "2", duration_max_days: "3")

    expect(dto.duration_min_days).to eq(2)
    expect(dto.duration_max_days).to eq(3)
  end

  it "ignores durations that are not usable numbers" do
    dto = described_class.new(duration_min_days: "soon", duration_max_days: "0")

    expect(dto.duration_min_days).to be_nil
    expect(dto.duration_max_days).to be_nil
  end

  it "converts the starting price into minor units" do
    expect(described_class.new(starting_price: "1999").starting_price_minor).to eq(199_900)
  end

  it "adds a scheme to a bare booking URL" do
    expect(described_class.new(booking_url: "anayabakes.com/book").booking_url)
      .to eq("https://anayabakes.com/book")
  end
end
