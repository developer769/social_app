require "rails_helper"

RSpec.describe Onboarding::SaveBusinessSetup do
  let(:workspace) { create(:workspace, name: "Untitled") }
  let(:actor) { workspace.owner_user }

  def dto(**overrides)
    Onboarding::BusinessSetupDto.new(
      business_name: "Anaya Bakes",
      category: "Bakery",
      business_type: "small_business",
      contact_email: "hello@anayabakes.com",
      phone: "+91 98765 43210",
      website_url: "www.anayabakes.com",
      city: "Delhi, India",
      timezone: "Asia/Kolkata",
      about: "We create fresh, handcrafted bakes.",
      goals: %w[increase_sales generate_leads],
      tones: %w[friendly elegant],
      **overrides
    )
  end

  it "saves the profile, renames the workspace and records goals and tones" do
    result = described_class.call(workspace: workspace, dto: dto, actor: actor)

    expect(result).to be_success
    expect(workspace.reload.name).to eq("Anaya Bakes")
    expect(workspace.brand_profile.category).to eq("Bakery")
    expect(workspace.brand_profile.website_url).to eq("https://www.anayabakes.com")
    expect(workspace.brand_goals.pluck(:goal)).to contain_exactly("increase_sales", "generate_leads")
    expect(workspace.brand_tones.pluck(:tone)).to contain_exactly("friendly", "elegant")
  end

  it "advances onboarding to the next step" do
    described_class.call(workspace: workspace, dto: dto, actor: actor)

    expect(workspace.reload.onboarding_step).to eq("catalog")
  end

  it "does not move progress backwards when the step is saved again later" do
    workspace.update!(onboarding_step: "health")

    described_class.call(workspace: workspace, dto: dto, actor: actor)

    expect(workspace.reload.onboarding_step).to eq("health")
  end

  it "replaces goals rather than accumulating them" do
    described_class.call(workspace: workspace, dto: dto, actor: actor)
    described_class.call(workspace: workspace, dto: dto(goals: %w[website_visits]), actor: actor)

    expect(workspace.reload.brand_goals.pluck(:goal)).to contain_exactly("website_visits")
  end

  it "is idempotent when submitted twice with the same data" do
    described_class.call(workspace: workspace, dto: dto, actor: actor)

    expect { described_class.call(workspace: workspace, dto: dto, actor: actor) }
      .not_to change(BrandGoal, :count)
  end

  it "writes an audit event" do
    expect { described_class.call(workspace: workspace, dto: dto, actor: actor) }
      .to change { AuditEvent.where(action: "onboarding.business_setup_saved").count }.by(1)
  end

  it "rolls the whole save back when the profile is invalid" do
    result = described_class.call(workspace: workspace, dto: dto(contact_email: "not-an-email"), actor: actor)

    expect(result).to be_failure
    expect(workspace.reload.name).to eq("Untitled")
    expect(workspace.brand_goals).to be_empty
    expect(workspace.onboarding_step).to eq("business_setup")
  end

  it "keeps each workspace's brand separate" do
    other = create(:workspace)
    create(:brand_goal, workspace: other, goal: "grow_followers")

    described_class.call(workspace: workspace, dto: dto, actor: actor)

    expect(other.reload.brand_goals.pluck(:goal)).to eq(%w[grow_followers])
  end
end
