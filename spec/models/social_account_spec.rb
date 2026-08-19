require "rails_helper"

RSpec.describe SocialAccount do
  let(:workspace) { create(:workspace) }

  def account(provider: "instagram", **attrs)
    described_class.create!(workspace: workspace, provider: provider,
                            external_account_id: "ext-#{provider}", **attrs)
  end

  it "reads its capabilities from the provider catalog" do
    expect(account(provider: "youtube").capabilities).not_to be_publish_image
  end

  it "renders the handle with the platform's own prefix" do
    expect(account(username: "anaya.bakes").handle).to eq("@anaya.bakes")
    expect(account(provider: "linkedin", username: "anaya-bakes").handle).to eq("anaya-bakes")
  end

  it "warns before the token dies, not after" do
    soon = account(token_expires_at: 3.days.from_now)

    expect(soon).to be_token_expiring_soon
    expect(soon).not_to be_token_expired
    expect(soon).to be_usable_for_publishing
  end

  it "is not usable for publishing once the token has expired" do
    expect(account(token_expires_at: 1.hour.ago)).not_to be_usable_for_publishing
  end

  it "is not usable for publishing once disconnected" do
    disconnected = account
    disconnected.mark_disconnected!

    expect(disconnected).not_to be_usable_for_publishing
  end

  it "marks permissions partial when the provider withholds a scope" do
    record = account
    profile = SocialProvider::ProfileDto.new(
      provider: "instagram", external_account_id: "ext-instagram",
      username: "anaya.bakes", granted_scopes: %w[publish_image]
    )

    record.mark_connected!(profile: profile)

    expect(record).to be_permission_partial
    expect(record.missing_scopes).to include("analytics")
  end

  it "refuses a provider outside the catalog" do
    record = described_class.new(workspace: workspace, provider: "myspace", external_account_id: "x")

    expect(record).not_to be_valid
  end

  it "refuses the same provider account twice in one workspace" do
    account

    expect { account }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
