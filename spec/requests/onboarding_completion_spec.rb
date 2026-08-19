require "rails_helper"

RSpec.describe "Onboarding completion" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "social health" do
    it "offers to calculate before a score exists" do
      get workspace_onboarding_health_path(**slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Calculate my score")
    end

    it "calculates a score and explains how it was reached" do
      expect { post workspace_onboarding_health_path(**slug) }
        .to change { workspace.social_health_scores.count }.by(1)

      follow_redirect!
      expect(response.body).to include("How this score is calculated")
      expect(response.body).to include("Profile completeness")
    end

    it "states plainly that the score is partial and why" do
      post workspace_onboarding_health_path(**slug)
      follow_redirect!

      expect(response.body).to include("60% of the full picture")
      expect(response.body).to include("excluded from this score")
    end

    # The design shows reach and engagement figures. Without a live account
    # those numbers do not exist, so the page must not present any.
    it "shows no invented performance figures" do
      post workspace_onboarding_health_path(**slug)
      follow_redirect!

      expect(response.body).to include("Not measured")
      expect(response.body).not_to match(/125\.4K|11\.2K/)
    end

    it "advances onboarding to the plan step" do
      post workspace_onboarding_health_complete_path(**slug)

      expect(response).to redirect_to(workspace_onboarding_plan_path(**slug))
      expect(workspace.reload.onboarding_step).to eq("plan")
    end
  end

  describe "choosing a plan" do
    before { load Rails.root.join("db/seeds/plans.rb") }

    it "lists the three plans with monthly pricing" do
      get workspace_onboarding_plan_path(**slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Basic", "Pro", "Business")
      expect(response.body).to include("₹499", "₹999", "₹1,999")
    end

    it "switches to annual pricing" do
      get workspace_onboarding_plan_path(**slug, interval: "year")

      expect(response.body).to include("₹4,990")
      expect(response.body).to include("you save")
    end

    it "ignores an interval it does not recognise rather than erroring" do
      get workspace_onboarding_plan_path(**slug, interval: "fortnightly")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("₹499")
    end

    it "says plainly that nothing is charged" do
      get workspace_onboarding_plan_path(**slug)

      expect(response.body).to include("Nothing is charged today")
    end

    it "starts a trial and finishes onboarding" do
      plan = Plan.find_by(code: "pro", interval: "month")

      post workspace_onboarding_plan_path(**slug), params: { plan_id: plan.id }

      expect(response).to redirect_to(workspace_root_path(**slug))
      expect(workspace.reload.onboarding_step).to eq("completed")
      expect(workspace.subscription.plan).to eq(plan)
    end

    it "sends a finished owner straight to the dashboard when they revisit onboarding" do
      post workspace_onboarding_plan_path(**slug), params: { plan_id: Plan.first.id }

      get workspace_onboarding_path(**slug)

      expect(response).to redirect_to(workspace_root_path(**slug))
    end

    it "rejects a plan id that does not exist" do
      post workspace_onboarding_plan_path(**slug), params: { plan_id: 0 }

      expect(workspace.reload.subscription).to be_nil
      expect(workspace.onboarding_step).not_to eq("completed")
    end
  end

  describe "tenant isolation" do
    let(:other) { create(:workspace) }

    before { create(:workspace_membership, workspace: other, user: create(:user)) }

    it "cannot calculate a score for another workspace" do
      post workspace_onboarding_health_path(workspace_slug: other.slug)

      expect(response).to have_http_status(:not_found)
      expect(other.social_health_scores).to be_empty
    end

    it "cannot start a trial on another workspace" do
      load Rails.root.join("db/seeds/plans.rb")

      post workspace_onboarding_plan_path(workspace_slug: other.slug), params: { plan_id: Plan.first.id }

      expect(response).to have_http_status(:not_found)
      expect(other.reload.subscription).to be_nil
    end
  end
end
