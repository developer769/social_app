require "rails_helper"

RSpec.describe "Team invitations" do
  let(:owner) { create(:user, name: "Anaya Sharma") }
  let(:workspace) { create(:workspace, owner_user: owner, name: "Anaya Bakes") }

  before { create(:workspace_membership, workspace: workspace, user: owner) }

  def slug = { workspace_slug: workspace.slug }

  def invite(email = "teammate@example.test")
    Team::InviteMember.call(workspace: workspace, email: email, actor: owner)
  end

  describe "inviting" do
    before { sign_in(owner) }

    it "creates a pending invitation and emails it" do
      expect {
        post workspace_settings_team_index_path(**slug), params: { email: "teammate@example.test" }
      }.to change { workspace.workspace_memberships.pending.count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it "stores only a digest of the token, never the token" do
      result = invite
      membership = result.value

      expect(membership.raw_invitation_token).to be_present
      expect(membership.invitation_token_digest)
        .to eq(WorkspaceMembership.digest(membership.raw_invitation_token))
      expect(WorkspaceMembership.where(invitation_token_digest: membership.raw_invitation_token)).to be_empty
    end

    it "refuses someone who is already in the workspace" do
      teammate = create(:user, email: "already@example.test")
      create(:workspace_membership, workspace: workspace, user: teammate)

      expect(invite("already@example.test").error).to eq(:already_a_member)
    end

    it "refuses an address that is not one" do
      expect(invite("not-an-email").error).to eq(:invalid_email)
    end

    # No role is chosen, because roles are deliberately undefined.
    it "offers no permission level, and says everyone gets the same access" do
      get workspace_settings_team_index_path(**slug)

      expect(response.body).to include("same access to this workspace")
      expect(response.body).not_to match(/name="role"|Administrator|Viewer/)
    end
  end

  describe "accepting" do
    it "creates an account for a new person and joins them" do
      membership = invite.value
      token = membership.raw_invitation_token

      expect {
        post accept_invitation_path(token: token),
             params: { user: { name: "Rhea Nair", password: "correct-horse-battery" } }
      }.to change(User, :count).by(1)

      joined = User.find_by(email: "teammate@example.test")
      expect(membership.reload).to be_grants_access
      expect(membership.user).to eq(joined)
      expect(response).to redirect_to(workspace_root_path(**slug))
    end

    it "signs the new person straight in" do
      token = invite.value.raw_invitation_token

      post accept_invitation_path(token: token),
           params: { user: { name: "Rhea Nair", password: "correct-horse-battery" } }
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Anaya Bakes")
    end

    it "joins an existing signed-in account without creating another" do
      existing = create(:user, email: "teammate@example.test")
      sign_in(existing)
      token = invite.value.raw_invitation_token

      expect { post accept_invitation_path(token: token) }.not_to change(User, :count)

      expect(existing.reload.workspaces).to include(workspace)
    end

    # The address is fixed to the one invited, so an invitation cannot be
    # redirected onto a different account by editing the form.
    it "ignores an email supplied in the form" do
      token = invite.value.raw_invitation_token

      post accept_invitation_path(token: token),
           params: { user: { name: "Rhea", password: "correct-horse-battery", email: "attacker@evil.test" } }

      expect(User.find_by(email: "attacker@evil.test")).to be_nil
      expect(User.find_by(email: "teammate@example.test")).to be_present
    end

    it "consumes the token, so the link cannot be reused" do
      token = invite.value.raw_invitation_token
      post accept_invitation_path(token: token),
           params: { user: { name: "Rhea", password: "correct-horse-battery" } }

      get invitation_path(token: token)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "a token that will not work" do
    # Unknown, cancelled and used tokens answer the same way, so guessing
    # reveals nothing about whether a token ever existed.
    it "answers identically for an unknown and a cancelled token" do
      get invitation_path(token: "completely-made-up-token")
      unknown = response.body

      membership = invite.value
      token = membership.raw_invitation_token
      membership.cancel_invitation!

      get invitation_path(token: token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq(unknown)
    end

    it "says plainly when an invitation has expired" do
      membership = invite.value
      token = membership.raw_invitation_token
      membership.update!(expires_at: 1.day.ago)

      get invitation_path(token: token)

      expect(response).to have_http_status(:gone)
      expect(response.body).to include("expired")
    end
  end

  describe "declining" do
    it "declines without creating anything" do
      membership = invite.value

      expect {
        delete decline_invitation_path(token: membership.raw_invitation_token)
      }.not_to change(User, :count)

      expect(membership.reload).to be_invitation_declined
    end
  end

  describe "removing someone" do
    before { sign_in(owner) }

    it "ends their access immediately, signing them out" do
      teammate = create(:user)
      membership = create(:workspace_membership, workspace: workspace, user: teammate)
      teammate_session = Session.start!(user: teammate)

      delete workspace_settings_team_path(**slug, id: membership)

      expect(membership.reload).not_to be_grants_access
      expect(teammate_session.reload.revoked_at).to be_present
    end

    # The creator holds operations nobody else can perform yet, so removing
    # them would leave the workspace unownable.
    it "refuses to remove the owner" do
      membership = workspace.workspace_memberships.find_by(user: owner)

      delete workspace_settings_team_path(**slug, id: membership)

      expect(membership.reload).to be_grants_access
      expect(flash[:alert]).to include("owner cannot be removed")
    end

    it "cancels a pending invitation rather than removing a member" do
      membership = invite.value

      delete workspace_settings_team_path(**slug, id: membership)

      expect(membership.reload).to be_invitation_cancelled
    end
  end

  describe "tenant isolation" do
    before { sign_in(owner) }

    it "cannot invite into another workspace" do
      other = create(:workspace)
      create(:workspace_membership, workspace: other, user: create(:user))

      post workspace_settings_team_index_path(workspace_slug: other.slug),
           params: { email: "someone@example.test" }

      expect(response).to have_http_status(:not_found)
      expect(other.workspace_memberships.pending).to be_empty
    end
  end
end
