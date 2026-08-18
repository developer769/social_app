require "rails_helper"

RSpec.describe Onboarding::BusinessSetupDto do
  it "is immutable once built" do
    expect(described_class.new(business_name: "Anaya Bakes")).to be_frozen
  end

  it "treats blank values as absent" do
    dto = described_class.new(business_name: "  ", category: "", about: "   ")

    expect(dto.business_name).to be_nil
    expect(dto.category).to be_nil
    expect(dto.about).to be_nil
  end

  it "adds a scheme to a bare domain, because owners type it that way" do
    expect(described_class.new(website_url: "www.anayabakes.com").website_url)
      .to eq("https://www.anayabakes.com")
  end

  it "leaves an explicit scheme alone" do
    expect(described_class.new(website_url: "http://anayabakes.com").website_url)
      .to eq("http://anayabakes.com")
  end

  it "keeps only the digits and plus sign of a phone number" do
    expect(described_class.new(phone: "+91 98765-43210").phone).to eq("+919876543210")
  end

  it "downcases the contact email" do
    expect(described_class.new(contact_email: " Hello@AnayaBakes.com ").contact_email)
      .to eq("hello@anayabakes.com")
  end

  it "drops goals and tones it does not recognise, so nothing reaches a check constraint" do
    dto = described_class.new(goals: %w[increase_sales world_domination], tones: %w[friendly sarcastic])

    expect(dto.goals).to eq(%w[increase_sales])
    expect(dto.tones).to eq(%w[friendly])
  end
end
