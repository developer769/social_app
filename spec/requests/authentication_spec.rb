require "rails_helper"

RSpec.describe "Authentication" do
  let!(:user) { create(:user) }

  describe "signing in" do
    it "starts a session and lands on the workspace" do
      workspace = create(:workspace, owner_user: user)
      create(:workspace_membership, workspace: workspace, user: user)

      sign_in(user)

      expect(response).to redirect_to(workspace_root_path(workspace_slug: workspace.slug))
      follow_redirect!
      expect(response.body).to include(workspace.name)
    end

    it "rejects a wrong password without revealing whether the email exists" do
      # The only legitimate difference between the two responses is the address
      # the visitor typed, which is echoed back into the form. Anything else
      # would tell an attacker which addresses have accounts.
      post login_path, params: { email: user.email, password: "wrong-password" }
      known_email_body = response.body.sub(user.email, "ADDRESS")
      known_email_status = response.status

      post login_path, params: { email: "nobody@nowhere.test", password: "wrong-password" }
      unknown_email_body = response.body.sub("nobody@nowhere.test", "ADDRESS")

      expect(response.status).to eq(known_email_status)
      expect(unknown_email_body).to eq(known_email_body)
    end

    it "records both success and failure in the audit trail" do
      expect { sign_in(user) }
        .to change { AuditEvent.where(action: "user.signed_in").count }.by(1)

      expect { post login_path, params: { email: user.email, password: "nope" } }
        .to change { AuditEvent.where(action: "user.sign_in_failed").count }.by(1)
    end
  end

  describe "signing out" do
    it "revokes the session so its cookie stops working" do
      workspace = create(:workspace, owner_user: user)
      create(:workspace_membership, workspace: workspace, user: user)
      sign_in(user)

      delete logout_path

      expect(Session.last.revoked_at).to be_present

      get workspace_root_path(workspace_slug: workspace.slug)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "unauthenticated access" do
    it "sends a signed-out visitor to the login page" do
      workspace = create(:workspace)

      get workspace_root_path(workspace_slug: workspace.slug)

      expect(response).to redirect_to(login_path)
    end
  end
end

RSpec.describe "First-time registration" do
  it "sends a brand new owner into onboarding, not the empty dashboard" do
    post signup_path, params: {
      user: { business_name: "Meera Flowers", name: "Meera Iyer",
              email: "meera@meeraflowers.test", password: "correct-horse-battery" }
    }

    workspace = Workspace.find_by(name: "Meera Flowers")
    expect(response).to redirect_to(workspace_onboarding_path(workspace_slug: workspace.slug))

    follow_redirect!
    follow_redirect!
    expect(response.body).to include("Step 1 of 6")
  end

  it "creates the user, workspace and membership together" do
    expect {
      post signup_path, params: {
        user: { business_name: "Meera Flowers", name: "Meera Iyer",
                email: "meera@meeraflowers.test", password: "correct-horse-battery" }
      }
    }.to change(User, :count).by(1)
     .and change(Workspace, :count).by(1)
     .and change(WorkspaceMembership, :count).by(1)

    expect(Workspace.last.workspace_memberships.sole).to be_grants_access
  end

  it "creates nothing when the details are unusable" do
    expect {
      post signup_path, params: {
        user: { business_name: "Meera Flowers", name: "Meera Iyer",
                email: "not-an-email", password: "short" }
      }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
