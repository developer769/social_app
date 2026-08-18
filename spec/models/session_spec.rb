require "rails_helper"

RSpec.describe Session do
  let(:user) { create(:user) }

  it "returns the raw token once and stores only its digest" do
    session = described_class.start!(user: user, ip_address: "203.0.113.4", user_agent: "rspec")

    expect(session.raw_token).to be_present
    expect(session.token_digest).to eq(described_class.digest(session.raw_token))
    expect(described_class.where(token_digest: session.raw_token)).to be_empty
  end

  it "authenticates a live session" do
    session = described_class.start!(user: user)

    expect(described_class.authenticate(session.raw_token)).to eq(session)
  end

  it "refuses a revoked session" do
    session = described_class.start!(user: user)
    raw = session.raw_token
    session.revoke!

    expect(described_class.authenticate(raw)).to be_nil
  end

  it "refuses an expired session" do
    session = described_class.start!(user: user)
    raw = session.raw_token
    session.update!(expires_at: 1.minute.ago)

    expect(described_class.authenticate(raw)).to be_nil
  end

  it "refuses a blank or unknown token" do
    expect(described_class.authenticate(nil)).to be_nil
    expect(described_class.authenticate("")).to be_nil
    expect(described_class.authenticate("not-a-real-token")).to be_nil
  end
end
