require "rails_helper"

RSpec.describe "Onboarding" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "resuming" do
    it "sends the owner to the first step when nothing is done yet" do
      get workspace_onboarding_path(**slug)

      expect(response).to redirect_to(workspace_onboarding_business_path(**slug))
    end

    it "sends the owner back to where they stopped" do
      workspace.update!(onboarding_step: "connections")

      get workspace_onboarding_path(**slug)

      expect(response).to redirect_to(workspace_onboarding_connections_path(**slug))
    end

    it "sends a finished owner to the dashboard" do
      workspace.update!(onboarding_step: "completed")

      get workspace_onboarding_path(**slug)

      expect(response).to redirect_to(workspace_root_path(**slug))
    end
  end

  describe "business setup" do
    it "renders the form with the six-step progress indicator" do
      get workspace_onboarding_business_path(**slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Step 1 of 6")
      expect(response.body).to include("Primary goals")
    end

    it "saves and moves on to the catalog step" do
      patch workspace_onboarding_business_path(**slug), params: {
        business_setup: { business_name: "Anaya Bakes", category: "Bakery", timezone: "Asia/Kolkata" },
        goals: %w[increase_sales],
        tones: %w[friendly]
      }

      expect(response).to redirect_to(workspace_onboarding_catalog_path(**slug))
      expect(workspace.reload.name).to eq("Anaya Bakes")
      expect(workspace.brand_goals.pluck(:goal)).to eq(%w[increase_sales])
    end

    it "re-renders with errors and saves nothing when the email is invalid" do
      patch workspace_onboarding_business_path(**slug), params: {
        business_setup: { business_name: "Anaya Bakes", contact_email: "nope" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(workspace.reload.brand_profile).to be_nil
    end

    it "ignores parameters that were not permitted" do
      patch workspace_onboarding_business_path(**slug), params: {
        business_setup: { business_name: "Anaya Bakes", onboarding_step: "completed" }
      }

      expect(workspace.reload.onboarding_step).to eq("catalog")
    end
  end

  describe "tenant isolation" do
    it "cannot open another workspace's onboarding" do
      other = create(:workspace)
      create(:workspace_membership, workspace: other, user: create(:user))

      get workspace_onboarding_business_path(workspace_slug: other.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot submit to another workspace's onboarding" do
      other = create(:workspace, name: "Kabir Coffee")
      create(:workspace_membership, workspace: other, user: create(:user))

      patch workspace_onboarding_business_path(workspace_slug: other.slug),
            params: { business_setup: { business_name: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(other.reload.name).to eq("Kabir Coffee")
    end
  end

  describe "every step is reachable" do
    OnboardingFlow.keys.each do |key|
      it "renders the #{key} step" do
        get OnboardingFlow.path_for(key, workspace)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
