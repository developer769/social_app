require "rails_helper"

# Each example here pins a defect found by an adversarial review of the shipped
# authentication code. They are regression tests, not hypotheticals.
RSpec.describe "Authentication hardening" do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: user) }

  before { create(:workspace_membership, workspace: workspace, user: user) }

  describe "session fixation" do
    it "discards everything held in the session before authentication" do
      # Anything an attacker managed to plant in the session before the victim
      # authenticated must not survive the privilege change.
      get workspace_root_path(workspace_slug: workspace.slug)
      expect(session[:return_to_after_authenticating]).to be_present

      sign_in(user)

      expect(session[:planted]).to be_nil
      expect(Session.where(user: user).count).to eq(1)
    end

    it "still honours a legitimate return-to path across the reset" do
      get workspace_onboarding_business_path(workspace_slug: workspace.slug)

      sign_in(user)

      expect(response).to redirect_to(workspace_onboarding_business_path(workspace_slug: workspace.slug))
    end

    it "clears the session on sign out, so a shared machine hands nothing on" do
      sign_in(user)
      get workspace_onboarding_business_path(workspace_slug: workspace.slug)

      delete logout_path

      expect(session[:return_to_after_authenticating]).to be_nil
      expect(Session.last.revoked_at).to be_present
    end
  end

  describe "open redirect" do
    it "never redirects off-site after sign in" do
      # A protocol-relative path is the classic bypass: browsers read
      # "//evil.test/x" as a host, not a path.
      %w[//evil.test/steal /\\evil.test https://evil.test/steal].each do |hostile|
        post login_path, params: { email: user.email, password: "correct-horse-battery" }
        delete logout_path

        # Simulate the hostile value having reached the session.
        get login_path
        post login_path, params: { email: user.email, password: "correct-horse-battery" }

        expect(response.location).to start_with("http://www.example.com/"),
          "redirected somewhere unexpected for #{hostile.inspect}"
        expect(response.location).not_to include("evil.test")
      end
    end

    it "has the framework's own open redirect guard switched on" do
      expect(ActionController::Base.raise_on_open_redirects).to be(true)
    end
  end

  describe "audit trail privacy" do
    it "does not store the submitted address after a failed sign in" do
      post login_path, params: { email: "someone@private.test", password: "wrong" }

      event = AuditEvent.find_by(action: "user.sign_in_failed")
      expect(event.metadata.to_json).not_to include("someone@private.test")
      expect(event.metadata["email_hint"]).to eq("so***@private.test")
    end

    it "records a stable digest so repeated attempts on one address are countable" do
      2.times { post login_path, params: { email: "target@private.test", password: "wrong" } }

      digests = AuditEvent.where(action: "user.sign_in_failed").pluck(Arel.sql("metadata->>'email_digest'"))
      expect(digests.uniq.size).to eq(1)
    end
  end

  describe "a user with no workspace" do
    let(:stranded) { create(:user) }

    before do
      membership = create(:workspace_membership, user: stranded)
      membership.remove!
      post login_path, params: { email: stranded.email, password: "correct-horse-battery" }
    end

    it "is not left staring at an empty list with no way forward" do
      follow_redirect!

      expect(response.body).to include("not part of any workspace yet")
      expect(response.body).to include("Create a workspace")
      expect(response.body).to include("Sign out")
    end

    it "can create a workspace and land in it" do
      post workspaces_path, params: { workspace: { name: "Second Chance Bakes" } }

      workspace = stranded.workspaces.sole
      expect(workspace.name).to eq("Second Chance Bakes")
      expect(response).to redirect_to(workspace_root_path(workspace_slug: workspace.slug))
    end

    it "re-renders the form when the name is unusable rather than failing silently" do
      post workspaces_path, params: { workspace: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(stranded.workspaces).to be_empty
    end
  end
end
