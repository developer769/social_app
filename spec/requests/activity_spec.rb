require "rails_helper"

RSpec.describe "Activity" do
  let(:owner) { create(:user, name: "Anaya Sharma") }
  let(:colleague) { create(:user, name: "Priya Nair") }
  let(:workspace) { create(:workspace, owner_user: owner, name: "Anaya Bakes") }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    create(:workspace_membership, workspace: workspace, user: colleague)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  def record(action, actor: owner, **rest)
    AuditEvent.record!(action: action, workspace: workspace, actor_user: actor, **rest)
  end

  it "reads as sentences rather than as event names" do
    record("social_account.connected", metadata: { provider: "instagram" })

    get workspace_settings_activity_path(**slug)

    expect(response.body).to include("connected Instagram")
    expect(response.body).not_to include("social_account.connected")
  end

  it "names the person who did it, and calls you you" do
    record("brand_kit.updated", actor: colleague)
    record("posting_preferences.updated", actor: owner)

    get workspace_settings_activity_path(**slug)

    expect(response.body).to include("Priya Nair").and include("You")
  end

  # Audit rows keep a slug so a rename cannot orphan them. The screen has to
  # turn that back into the name the owner actually recognises.
  it "names a style rather than printing its slug" do
    template = create(:template, slug: "weekend-indulgence-photo", name: "Weekend Indulgence")
    record("creative.requested", metadata: { template: template.slug })

    get workspace_settings_activity_path(**slug)

    expect(response.body).to include("asked for pictures from Weekend Indulgence")
    expect(response.body).not_to include("weekend-indulgence-photo")
  end

  it "still names a style that has been deleted since" do
    record("creative.requested", metadata: { template: "festive-hamper-photo" })

    get workspace_settings_activity_path(**slug)

    expect(response.body).to include("Festive Hamper Photo")
  end

  # An allowlist, so an audit action added tomorrow cannot put its own metadata
  # on a customer's screen before anyone has decided how it should read.
  it "ignores an action nobody has written a phrasing for" do
    record("something.nobody.phrased", metadata: { secret: "should-never-render" })

    get workspace_settings_activity_path(**slug)

    expect(response.body).not_to include("should-never-render")
    expect(response.body).to include("Nothing has happened yet")
  end

  describe "what stays private" do
    # Everyone in a workspace has a reason to know a post was deleted. Nobody
    # else needs to know when a colleague changed their password.
    it "hides a colleague's password change" do
      record("user.password_changed", actor: colleague)

      get workspace_settings_activity_path(**slug)

      expect(response.body).not_to include("changed their password")
    end

    it "shows you your own password change" do
      record("user.password_changed", actor: owner)

      get workspace_settings_activity_path(**slug)

      expect(response.body).to include("changed their password")
    end
  end

  describe "the record itself" do
    it "cannot be edited by anyone, including us" do
      event = record("brand_kit.updated")

      expect { event.update!(action: "something.else") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  # Spec 7.
  it "shows nothing from another workspace" do
    other = create(:workspace)
    AuditEvent.record!(action: "social_account.connected", workspace: other,
                       actor_user: create(:user, name: "Someone Else"),
                       metadata: { provider: "linkedin" })

    get workspace_settings_activity_path(**slug)

    expect(response.body).not_to include("Someone Else")
    expect(response.body).not_to include("connected LinkedIn")
  end

  describe "paging" do
    it "offers older entries only when there are some" do
      record("brand_kit.updated")

      get workspace_settings_activity_path(**slug)

      expect(response.body).to include("End of the record")
    end

    it "walks back through the record without repeating itself" do
      45.times { record("brand_kit.updated") }

      get workspace_settings_activity_path(**slug)
      expect(response.body).to include("Older")

      get workspace_settings_activity_path(**slug, page: 2)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Newer")
    end
  end
end
