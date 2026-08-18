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

  it "does not grant access from a pending invitation alone" do
    invited_only = create(:workspace)
    create(:workspace_membership, :pending, workspace: invited_only, invitation_email: member.email)

    get workspace_root_path(workspace_slug: invited_only.slug)

    expect(response).to have_http_status(:not_found)
  end
end
