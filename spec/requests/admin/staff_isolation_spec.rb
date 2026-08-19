require "rails_helper"

# A staff account can publish to every workspace's gallery, so the boundary
# between the customer application and the staff area is the most important
# property in this feature.
RSpec.describe "Staff area isolation" do
  let(:staff) { create(:staff_user) }
  let(:customer) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: customer) }

  before { create(:workspace_membership, workspace: workspace, user: customer) }

  def sign_in_staff(account = staff)
    post admin_login_path, params: { email: account.email, password: "correct-horse-battery-staple" }
  end

  describe "a customer" do
    before { sign_in(customer) }

    it "cannot reach the staff area with a valid customer session" do
      get admin_templates_path

      expect(response).to redirect_to(admin_login_path)
    end

    it "cannot publish a template" do
      template = create(:template, draft: true)

      post publish_admin_template_path(template)

      expect(response).to redirect_to(admin_login_path)
      expect(template.reload).not_to be_published
    end

    it "has no attribute that could make them staff" do
      expect(User.column_names).not_to include("staff", "admin", "is_admin", "role")
    end
  end

  describe "a staff member" do
    before { sign_in_staff }

    it "reaches the staff area" do
      get admin_templates_path

      expect(response).to have_http_status(:ok)
    end

    it "cannot reach a customer workspace with a staff session" do
      get workspace_root_path(workspace_slug: workspace.slug)

      expect(response).to redirect_to(login_path)
    end

    it "holds a session that is not a customer session" do
      expect(StaffSession.count).to eq(1)
      expect(Session.count).to eq(0)
    end
  end

  describe "signing in" do
    it "answers identically for an unknown address, a wrong password and a deactivated account" do
      deactivated = create(:staff_user, email: "gone@prachar.test")
      deactivated.deactivate!

      post admin_login_path, params: { email: "nobody@prachar.test", password: "wrong-password-here" }
      unknown = response.body

      post admin_login_path, params: { email: staff.email, password: "wrong-password-here" }
      wrong_password = response.body

      post admin_login_path, params: { email: deactivated.email, password: "correct-horse-battery-staple" }
      deactivated_body = response.body

      expect(wrong_password).to eq(unknown)
      expect(deactivated_body).to eq(unknown)
    end

    it "does not record the submitted address" do
      post admin_login_path, params: { email: "someone@private.test", password: "wrong-password-here" }

      event = StaffAuditEvent.find_by(action: "staff.sign_in_failed")
      expect(event.metadata.to_json).not_to include("someone@private.test")
    end

    it "refuses a deactivated account even with the right password" do
      staff.deactivate!

      sign_in_staff

      expect(response).to have_http_status(:unprocessable_content)
      get admin_templates_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "revokes live sessions when an account is deactivated" do
      sign_in_staff
      expect(StaffSession.active.count).to eq(1)

      staff.deactivate!

      expect(StaffSession.active.count).to eq(0)
      get admin_templates_path
      expect(response).to redirect_to(admin_login_path)
    end
  end
end
