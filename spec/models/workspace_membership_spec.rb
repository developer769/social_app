require "rails_helper"

RSpec.describe WorkspaceMembership do
  describe "invitation lifecycle" do
    let(:workspace) { create(:workspace) }
    let(:inviter) { workspace.owner_user }

    it "issues an invitation and exposes the raw token only in memory" do
      membership = create(:workspace_membership, :pending, workspace: workspace)

      membership.issue_invitation!(invited_by: inviter)

      expect(membership.raw_invitation_token).to be_present
      expect(membership.invitation_token_digest)
        .to eq(described_class.digest(membership.raw_invitation_token))
      expect(described_class.find(membership.id).raw_invitation_token).to be_nil
    end

    it "finds a membership by its raw token but never stores that token" do
      membership = create(:workspace_membership, :pending, workspace: workspace)
      membership.issue_invitation!(invited_by: inviter)
      raw = membership.raw_invitation_token

      expect(described_class.find_by_invitation_token(raw)).to eq(membership)
      expect(described_class.where(invitation_token_digest: raw)).to be_empty
    end

    it "grants access once accepted and clears the token" do
      membership = create(:workspace_membership, :pending, workspace: workspace)
      membership.issue_invitation!(invited_by: inviter)
      invitee = create(:user)

      membership.accept_invitation!(user: invitee)

      expect(membership).to be_grants_access
      expect(membership.invitation_token_digest).to be_nil
      expect(membership.accepted_at).to be_present
    end

    it "does not grant access when declined, cancelled or removed" do
      declined = create(:workspace_membership, :pending, workspace: workspace)
      declined.decline_invitation!

      cancelled = create(:workspace_membership, :pending, workspace: workspace)
      cancelled.cancel_invitation!

      removed = create(:workspace_membership, :removed, workspace: workspace)

      expect(declined).not_to be_grants_access
      expect(cancelled).not_to be_grants_access
      expect(removed).not_to be_grants_access
    end

    it "reports an invitation past its expiry as expired" do
      membership = create(:workspace_membership, :pending, workspace: workspace, expires_at: 1.day.ago)

      expect(membership).to be_invitation_expired
    end
  end

  describe "database constraints" do
    it "refuses a second membership for the same user in one workspace" do
      existing = create(:workspace_membership)
      duplicate = build(:workspace_membership, workspace: existing.workspace, user: existing.user)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a second pending invitation for the same email in one workspace" do
      existing = create(:workspace_membership, :pending)
      duplicate = build(:workspace_membership, :pending,
                        workspace: existing.workspace,
                        invitation_email: existing.invitation_email)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same person to be a member of two different workspaces" do
      first = create(:workspace_membership)
      second = build(:workspace_membership, user: first.user)

      expect { second.save! }.to change(described_class, :count).by(1)
    end

    it "refuses a row that identifies nobody" do
      membership = build(:workspace_membership, user: nil, invitation_email: nil)

      expect(membership).not_to be_valid
      expect { membership.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "refuses an accepted invitation with no user attached" do
      membership = build(:workspace_membership, :pending, invitation_status: "accepted", user: nil)

      expect { membership.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "has no role or permission column, because roles are deliberately deferred" do
      expect(described_class.column_names).not_to include("role", "permissions", "permission_level")
    end
  end
end
