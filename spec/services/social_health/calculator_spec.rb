require "rails_helper"

RSpec.describe SocialHealth::Calculator do
  let(:workspace) { create(:workspace) }

  def component(outcome, key) = outcome.components.find { |c| c.key == key }

  describe "honesty about what could be measured" do
    # The heart of this screen. The design shows 82/100 with reach and
    # engagement figures; with no live account those figures do not exist, and
    # scoring them as zero would be a performance claim we cannot support.
    it "never scores an unmeasurable signal as zero" do
      outcome = described_class.call(workspace: workspace)

      %w[reach engagement posting_consistency].each do |key|
        expect(component(outcome, key)).not_to be_measured
        expect(component(outcome, key).value).to be_nil
        expect(component(outcome, key).reason).to be_present
      end
    end

    it "reports coverage so a partial score cannot pass as a complete one" do
      outcome = described_class.call(workspace: workspace)

      expect(outcome.coverage_percentage).to eq(60)
    end

    it "excludes unmeasured weight from the score rather than diluting it" do
      # Everything measurable is perfect. The score must be 100 despite three
      # signals being unavailable -- if unavailable counted as zero it would be 60.
      create(:brand_profile, workspace: workspace, category: "Bakery", business_type: "small_business",
             contact_email: "hello@anayabakes.test", phone: "+919876543210",
             city: "Delhi, India", about: "Handcrafted bakes.")
      workspace.brand_profile.logo.attach(
        io: StringIO.new("x"), filename: "logo.png", content_type: "image/png"
      )
      create(:brand_goal, workspace: workspace)
      create(:brand_tone, workspace: workspace)
      # Five items is where catalog breadth reaches full marks.
      5.times { create(:product, workspace: workspace, description: "Lovely.", featured: true) }
      %w[instagram facebook linkedin].each do |provider|
        Connections::ConnectAccount.call(workspace: workspace, provider: provider, actor: workspace.owner_user)
      end

      outcome = described_class.call(workspace: workspace.reload)

      expect(outcome.score).to eq(100)
      expect(outcome.rating).to eq("excellent")
      expect(outcome.coverage_percentage).to eq(60)
    end

    it "explains why performance is unavailable, differently for each cause" do
      no_account = described_class.call(workspace: workspace)
      expect(component(no_account, "reach").reason).to include("Connect a social account")

      Connections::ConnectAccount.call(
        workspace: workspace, provider: "instagram", actor: workspace.owner_user
      )
      mocked = described_class.call(workspace: workspace.reload)
      expect(component(mocked, "reach").reason).to include("simulated")
    end
  end

  describe "measured signals" do
    it "scores an empty workspace at zero without erroring" do
      outcome = described_class.call(workspace: workspace)

      expect(outcome.score).to eq(0)
      expect(outcome.rating).to eq("needs_work")
    end

    it "scores profile completeness from the fields actually filled in" do
      create(:brand_profile, workspace: workspace, category: "Bakery",
             business_type: "small_business", city: "Delhi, India")

      outcome = described_class.call(workspace: workspace.reload)

      expect(component(outcome, "profile_completeness").value).to eq(43)
      expect(component(outcome, "profile_completeness").detail).to include("a logo")
    end

    it "rewards a catalog that is broad, described, priced and has a featured item" do
      5.times { create(:product, workspace: workspace, description: "Rich and chocolatey.", featured: true) }

      expect(component(described_class.call(workspace: workspace.reload), "catalog_readiness").value).to eq(100)
    end

    it "scores a thin catalog below a broad one, even when every item is complete" do
      2.times { create(:product, workspace: workspace, description: "Rich and chocolatey.", featured: true) }

      expect(component(described_class.call(workspace: workspace.reload), "catalog_readiness").value).to eq(76)
    end

    it "penalises a catalog with no descriptions" do
      3.times { create(:product, workspace: workspace, description: nil, featured: false) }

      value = component(described_class.call(workspace: workspace.reload), "catalog_readiness").value
      expect(value).to be < 100
    end

    it "counts breadth and health of connections" do
      Connections::ConnectAccount.call(
        workspace: workspace, provider: "instagram", actor: workspace.owner_user
      )

      component = component(described_class.call(workspace: workspace.reload), "account_coverage")

      expect(component.value).to be_between(1, 99)
      expect(component.findings.map { |f| f["text"] }).to include(a_string_matching(/1 account connected/))
    end
  end

  describe "ratings" do
    it "maps scores onto the published bands" do
      expect(described_class::RATINGS.map(&:last)).to eq(%w[excellent good fair needs_work])
    end
  end

  it "weights sum to one hundred, so a component cannot be silently dropped" do
    outcome = described_class.call(workspace: workspace)

    expect(outcome.components.sum(&:weight)).to eq(100)
  end
end
