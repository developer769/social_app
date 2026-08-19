require "rails_helper"

RSpec.describe Connections::ConnectAccount do
  let(:workspace) { create(:workspace) }
  let(:actor) { workspace.owner_user }

  it "connects an account and stores its handle" do
    result = described_class.call(workspace: workspace, provider: "instagram", actor: actor)

    expect(result).to be_success
    account = result.value
    expect(account).to be_connection_connected
    expect(account.provider).to eq("instagram")
    expect(account.handle).to start_with("@")
  end

  it "encrypts the access token at rest" do
    account = described_class.call(workspace: workspace, provider: "instagram", actor: actor).value

    stored = ActiveRecord::Base.connection.select_value(
      "SELECT access_token FROM social_credentials WHERE social_account_id = #{account.id}"
    )

    expect(account.social_credential.access_token).to be_present
    expect(stored).not_to include(account.social_credential.access_token)
  end

  it "keeps the token out of the audit trail" do
    account = described_class.call(workspace: workspace, provider: "instagram", actor: actor).value
    event = AuditEvent.find_by(action: "social_account.connected", auditable_id: account.id)

    expect(event.metadata.to_json).not_to include(account.social_credential.access_token)
    expect(event.metadata["provider"]).to eq("instagram")
  end

  it "reconnecting the same account updates it instead of duplicating it" do
    first = described_class.call(workspace: workspace, provider: "instagram", actor: actor).value
    second = described_class.call(workspace: workspace, provider: "instagram", actor: actor).value

    expect(second.id).to eq(first.id)
    expect(workspace.social_accounts.for_provider("instagram").count).to eq(1)
  end

  it "refuses a provider it does not know" do
    result = described_class.call(workspace: workspace, provider: "myspace", actor: actor)

    expect(result).to be_failure
    expect(result.error).to eq(:unknown_provider)
  end

  it "lets two workspaces connect independently" do
    other = create(:workspace)

    described_class.call(workspace: workspace, provider: "instagram", actor: actor)
    described_class.call(workspace: other, provider: "instagram", actor: other.owner_user)

    expect(workspace.social_accounts.count).to eq(1)
    expect(other.social_accounts.count).to eq(1)
    expect(other.social_accounts.first.external_account_id)
      .not_to eq(workspace.social_accounts.first.external_account_id)
  end
end
