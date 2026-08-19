require "rails_helper"

RSpec.describe "Social connections" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  it "lists every supported provider" do
    get workspace_onboarding_connections_path(**slug)

    expect(response).to have_http_status(:ok)
    SocialProvider::Catalog.all.each do |provider|
      expect(response.body).to include(provider.name)
    end
  end

  it "says plainly that the connections are simulated while no real adapter exists" do
    get workspace_onboarding_connections_path(**slug)

    expect(response.body).to include("simulated")
  end

  it "connects a provider" do
    post workspace_social_accounts_path(**slug, provider: "instagram")

    expect(response).to redirect_to(workspace_onboarding_connections_path(**slug))
    expect(workspace.social_accounts.for_provider("instagram").sole).to be_connection_connected
  end

  it "disconnects a provider and destroys its stored token" do
    account = Connections::ConnectAccount.call(
      workspace: workspace, provider: "instagram", actor: owner
    ).value

    expect { delete workspace_social_account_path(**slug, id: account) }
      .to change(SocialCredential, :count).by(-1)

    expect(account.reload).to be_connection_disconnected
  end

  it "advances onboarding to the analysis step" do
    post workspace_onboarding_connections_complete_path(**slug)

    expect(response).to redirect_to(workspace_onboarding_analysis_path(**slug))
    expect(workspace.reload.onboarding_step).to eq("analysis")
  end

  describe "tenant isolation" do
    let(:other) { create(:workspace) }

    before { create(:workspace_membership, workspace: other, user: create(:user)) }

    it "cannot connect an account into another workspace" do
      post workspace_social_accounts_path(workspace_slug: other.slug, provider: "instagram")

      expect(response).to have_http_status(:not_found)
      expect(other.social_accounts).to be_empty
    end

    it "cannot disconnect another workspace's account" do
      theirs = Connections::ConnectAccount.call(
        workspace: other, provider: "instagram", actor: other.owner_user
      ).value

      delete workspace_social_account_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).to be_connection_connected
    end
  end
end
