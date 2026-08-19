require "rails_helper"

# The proof required by spec 7: one workspace cannot reach another's records,
# and the slug in the URL grants nothing on its own.
RSpec.describe "Workspace isolation" do
  let(:member) { create(:user) }
  let(:mine) { create(:workspace, name: "Anaya Bakes") }
  let(:theirs) { create(:workspace, name: "Kabir Coffee") }

  before do
    create(:workspace_membership, workspace: mine, user: member)
    create(:workspace_membership, workspace: theirs, user: create(:user))
    sign_in(member)
  end

  it "serves a workspace the user belongs to" do
    get workspace_root_path(workspace_slug: mine.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Anaya Bakes")
  end

  it "returns not found for a workspace the user does not belong to" do
    get workspace_root_path(workspace_slug: theirs.slug)

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Kabir Coffee")
  end

  it "returns not found for a workspace that does not exist" do
    get workspace_root_path(workspace_slug: "no-such-business")

    expect(response).to have_http_status(:not_found)
  end

  it "stops serving a workspace once the membership is removed" do
    membership = member.workspace_memberships.find_by(workspace: mine)

    membership.remove!

    get workspace_root_path(workspace_slug: mine.slug)
    expect(response).to have_http_status(:not_found)
  end

  describe "what the person actually sees" do
    # A signed-in person who follows a stale link or mistypes a slug is not an
    # attacker. A bare RecordNotFound told them nothing and offered no way out.
    it "explains the situation and offers the workspaces they can open" do
      get workspace_root_path(workspace_slug: theirs.slug)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("available to you")
      expect(response.body).to include("Anaya Bakes")
      expect(response.body).to include("Sign out")
    end

    # The friendlier page must still not become an oracle for which workspaces
    # exist.
    it "responds identically whether the workspace exists or not" do
      get workspace_root_path(workspace_slug: theirs.slug)
      existing = response.body.gsub(/(content|value)="[^"]*"/, "")

      get workspace_root_path(workspace_slug: "definitely-not-a-real-workspace")
      absent = response.body.gsub(/(content|value)="[^"]*"/, "")

      expect(absent).to eq(existing)
    end

    it "does not echo the slug that was attempted" do
      get workspace_root_path(workspace_slug: theirs.slug)

      expect(response.body).not_to include(theirs.slug)
    end

    it "offers a way forward when they belong to nothing at all" do
      mine.workspace_memberships.find_by(user: member).remove!

      get workspace_root_path(workspace_slug: theirs.slug)

      expect(response.body).to include("a member of any workspace yet")
      expect(response.body).to include("Create a workspace")
    end
  end

  it "does not grant access from a pending invitation alone" do
    invited_only = create(:workspace)
    create(:workspace_membership, :pending, workspace: invited_only, invitation_email: member.email)

    get workspace_root_path(workspace_slug: invited_only.slug)

    expect(response).to have_http_status(:not_found)
  end
end
