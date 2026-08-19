require "rails_helper"

RSpec.describe SocialProvider::Catalog do
  it "covers the seven providers the specification names" do
    expect(described_class.keys).to match_array(
      %w[instagram facebook linkedin youtube tiktok google_business x]
    )
  end

  # These guard the promises the interface makes to a shop owner. If a platform
  # genuinely gains a capability, the change belongs here and these specs should
  # be updated deliberately, not by accident.
  it "does not claim image posting on video-only platforms" do
    expect(described_class.capabilities_for("youtube")).not_to be_publish_image
    expect(described_class.capabilities_for("tiktok")).not_to be_publish_image
  end

  it "does not claim video on Google Business Profile" do
    expect(described_class.capabilities_for("google_business")).not_to be_publish_video
  end

  it "does not claim direct messages on LinkedIn" do
    expect(described_class.capabilities_for("linkedin")).not_to be_direct_messages
  end

  it "keeps X to its short caption limit" do
    expect(described_class.capabilities_for("x").max_caption_length).to eq(280)
  end

  it "records the tight daily publishing limits that shape scheduling" do
    expect(described_class.capabilities_for("youtube").daily_publish_limit).to eq(6)
    expect(described_class.capabilities_for("instagram").daily_publish_limit).to eq(25)
  end

  it "gives every provider a caption limit, since every post is validated against one" do
    described_class.all.each do |provider|
      expect(provider.capabilities.max_caption_length).to be_present, "#{provider.key} has no caption limit"
    end
  end

  it "returns nothing for an unknown provider rather than guessing" do
    expect(described_class.find("myspace")).to be_nil
  end
end
