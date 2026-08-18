require "rails_helper"

RSpec.describe Workspace do
  describe "tenant isolation" do
    it "exposes only the workspaces a user has accepted and active membership in" do
      user = create(:user)

      visible = create(:workspace)
      create(:workspace_membership, workspace: visible, user: user)

      other = create(:workspace)
      create(:workspace_membership, workspace: other, user: create(:user))

      pending_invite = create(:workspace)
      create(:workspace_membership, :pending, workspace: pending_invite, invitation_email: user.email)

      removed = create(:workspace)
      create(:workspace_membership, :removed, workspace: removed, user: user)

      expect(user.workspaces).to contain_exactly(visible)
      expect(user.member_of?(other)).to be(false)
      expect(user.member_of?(pending_invite)).to be(false)
      expect(user.member_of?(removed)).to be(false)
    end
  end

  describe "market defaults" do
    it "defaults to India without hardcoding it into the domain" do
      workspace = create(:workspace)

      expect(workspace.currency).to eq("INR")
      expect(workspace.timezone).to eq("Asia/Kolkata")
      expect(workspace.locale).to eq("en-IN")
    end

    it "accepts a different market per workspace" do
      workspace = create(:workspace, currency: "GBP", timezone: "Europe/London", locale: "en-GB", country_code: "GB")

      expect(workspace).to be_valid
      expect(workspace.reload.currency).to eq("GBP")
    end
  end

  describe "slug generation" do
    it "derives a url-safe slug from the name" do
      expect(create(:workspace, name: "Anaya Bakes and Co").slug).to start_with("anaya-bakes-and-co")
    end

    it "does not collide when two workspaces share a name" do
      first = create(:workspace, name: "Anaya Bakes")
      second = create(:workspace, name: "Anaya Bakes")

      expect(second.slug).not_to eq(first.slug)
    end

    it "rejects a slug that is not url-safe" do
      expect(build(:workspace, slug: "Not A Slug")).not_to be_valid
    end
  end

  describe "#owned_by?" do
    it "is true only for the creator" do
      workspace = create(:workspace)

      expect(workspace.owned_by?(workspace.owner_user)).to be(true)
      expect(workspace.owned_by?(create(:user))).to be(false)
      expect(workspace.owned_by?(nil)).to be(false)
    end
  end
end
