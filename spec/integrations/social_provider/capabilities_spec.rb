require "rails_helper"

RSpec.describe SocialProvider::Capabilities do
  it "answers only for capabilities it was given" do
    capabilities = described_class.new(supports: %i[publish_video analytics])

    expect(capabilities).to be_publish_video
    expect(capabilities).not_to be_publish_image
    expect(capabilities).not_to be_direct_messages
  end

  it "refuses a capability flag that does not exist, so a typo cannot silently disable a feature" do
    expect { described_class.new(supports: %i[publish_hologram]) }
      .to raise_error(ArgumentError, /unknown capability flags: publish_hologram/)
  end

  it "is immutable" do
    expect(described_class.new(supports: %i[analytics])).to be_frozen
  end

  it "exposes limits without inventing defaults" do
    capabilities = described_class.new(supports: [], limits: { max_caption_length: 280 })

    expect(capabilities.max_caption_length).to eq(280)
    expect(capabilities.max_hashtags).to be_nil
  end
end
