require "rails_helper"

RSpec.describe "Brand analysis" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  it "offers to start an analysis before one exists" do
    get workspace_onboarding_analysis_path(**slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Start analysis")
  end

  it "creates every task up front and enqueues one job each" do
    expect { post workspace_onboarding_analysis_path(**slug) }
      .to change { workspace.brand_analyses.count }.by(1)
      .and have_enqueued_job(Analysis::RunTaskJob).exactly(BrandAnalysis::TASK_KEYS.size).times

    expect(workspace.brand_analyses.sole.tasks.pluck(:task_key))
      .to match_array(BrandAnalysis::TASK_KEYS)
  end

  it "shows every task as pending before any job runs, rather than an empty list" do
    post workspace_onboarding_analysis_path(**slug)
    follow_redirect!

    expect(response.body).to include("Profile health")
    expect(response.body).to include("Pending")
    expect(response.body).to include("0<span class=\"text-lg\">%</span>")
  end

  it "reports real progress once tasks finish" do
    post workspace_onboarding_analysis_path(**slug)
    analysis = workspace.brand_analyses.sole
    analysis.tasks.first.finish!(outcome: "analysed")

    get workspace_onboarding_analysis_path(**slug)

    expect(response.body).to include("14<span class=\"text-lg\">%</span>")
  end

  it "advances onboarding to the health step" do
    post workspace_onboarding_analysis_complete_path(**slug)

    expect(response).to redirect_to(workspace_onboarding_health_path(**slug))
    expect(workspace.reload.onboarding_step).to eq("health")
  end

  it "cannot start an analysis in another workspace" do
    other = create(:workspace)
    create(:workspace_membership, workspace: other, user: create(:user))

    post workspace_onboarding_analysis_path(workspace_slug: other.slug)

    expect(response).to have_http_status(:not_found)
    expect(other.brand_analyses).to be_empty
  end
end
