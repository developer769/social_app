require "rails_helper"

# Removal only ever worked top-down. Somebody invited to help with a friend's
# bakery had no way out of it themselves.
RSpec.describe "Leaving a workspace" do
  let(:owner) { create(:user, name: "Anaya Sharma") }
  let(:teammate) { create(:user, name: "Priya Nair") }
  let(:workspace) { create(:workspace, owner_user: owner, name: "Anaya Bakes") }
  let!(:owner_membership) { create(:workspace_membership, workspace: workspace, user: owner) }
  let!(:teammate_membership) { create(:workspace_membership, workspace: workspace, user: teammate) }

  def slug = { workspace_slug: workspace.slug }

  describe "as a teammate" do
    before { sign_in(teammate) }

    it "is offered on the team page" do
      get workspace_settings_team_index_path(**slug)

      expect(response.body).to include("Leave this workspace")
    end

    it "ends your own access and nobody else's" do
      delete leave_workspace_settings_team_index_path(**slug)

      expect(teammate_membership.reload).not_to be_grants_access
      expect(owner_membership.reload).to be_grants_access
    end

    it "cannot reach the workspace afterwards" do
      delete leave_workspace_settings_team_index_path(**slug)

      get workspace_settings_team_index_path(**slug)

      expect(response).to have_http_status(:not_found)
    end

    it "leaves a record of who left" do
      expect { delete leave_workspace_settings_team_index_path(**slug) }
        .to change { AuditEvent.where(action: "workspace_membership.left").count }.by(1)
    end

    # It takes no id, so it cannot be aimed at anybody else. That is what makes
    # it safe without a permission level -- and there are none (spec 2).
    it "takes no target, so it cannot remove a colleague" do
      delete leave_workspace_settings_team_index_path(**slug), params: { id: owner_membership.id }

      expect(owner_membership.reload).to be_grants_access
      expect(teammate_membership.reload).not_to be_grants_access
    end
  end

  describe "as the person who created it" do
    before { sign_in(owner) }

    # Billing and ownership sit with the creator until roles are defined, so a
    # workspace they walked out of would be one nobody could look after.
    it "is not offered" do
      get workspace_settings_team_index_path(**slug)

      expect(response.body).not_to include("Leave this workspace")
    end

    it "is refused even when asked for directly" do
      delete leave_workspace_settings_team_index_path(**slug)

      expect(owner_membership.reload).to be_grants_access
      expect(flash[:alert]).to include("cannot leave")
    end
  end
end
