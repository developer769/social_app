require "rails_helper"

RSpec.describe "A finished workspace with nothing in it" do
  let(:owner) { create(:user) }
  let!(:workspace) do
    create(:workspace, owner_user: owner, onboarding_step: "completed",
           onboarding_completed_at: Time.current)
  end

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    create(:brand_profile, workspace: workspace)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  it "renders the dashboard" do
    get workspace_root_path(**slug)
    expect(response).to have_http_status(:ok)
  end

  %w[month week day agenda].each do |view|
    it "renders the #{view} calendar with no posts and no accounts" do
      get workspace_calendar_path(**slug, view: view)
      expect(response).to have_http_status(:ok)
    end
  end

  it "renders the new post form with no accounts connected" do
    get new_workspace_post_path(**slug)
    expect(response).to have_http_status(:ok)
  end
end
