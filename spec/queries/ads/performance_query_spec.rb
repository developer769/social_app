require "rails_helper"

RSpec.describe Ads::PerformanceQuery do
  let(:workspace) { create(:workspace) }
  let(:post) { create(:post, workspace: workspace) }

  def campaign_on(provider, **overrides)
    account = create(:social_account, workspace: workspace, provider: provider)
    create(:ad_campaign, workspace: workspace, post: post, social_account: account,
                         provider: provider, **overrides)
  end

  def measure(campaign, on: Date.current, **figures)
    create(:ad_metric, ad_campaign: campaign, on_date: on, **figures)
  end

  def total(key) = described_class.new(workspace: workspace).totals.find { |t| t.key == key }

  describe "when nothing has been reported" do
    it "reports every figure as unmeasured rather than zero" do
      campaign_on("instagram")

      expect(described_class.new(workspace: workspace).totals).to all(satisfy { |t| !t.measured? })
    end

    # A campaign that achieved nothing and a campaign nobody has told us about
    # are different situations.
    it "knows the difference between no data and no result" do
      query = described_class.new(workspace: workspace)
      campaign_on("instagram")

      expect(query.any_campaigns?).to be(true)
      expect(described_class.new(workspace: workspace).any_measurements?).to be(false)
    end
  end

  describe "adding up what was reported" do
    it "sums spend across campaigns and days" do
      campaign = campaign_on("instagram")
      measure(campaign, on: Date.current, spend_minor: 45_000)
      measure(campaign, on: 1.day.ago.to_date, spend_minor: 30_000)

      expect(total(:spend).value).to eq(75_000)
      expect(described_class.new(workspace: workspace).total_spend.minor_units).to eq(75_000)
    end

    it "ignores days outside the window" do
      campaign = campaign_on("instagram")
      measure(campaign, on: Date.current, spend_minor: 45_000)
      measure(campaign, on: 60.days.ago.to_date, spend_minor: 999_000)

      expect(described_class.new(workspace: workspace, days: 30).totals.find { |t| t.key == :spend }.value)
        .to eq(45_000)
      expect(described_class.new(workspace: workspace, days: 90).totals.find { |t| t.key == :spend }.value)
        .to eq(1_044_000)
    end
  end

  # The heart of it. "LinkedIn does not report reach" and "nobody was reached"
  # are different statements, and only one of them is true.
  describe "a figure a platform does not report" do
    before do
      instagram = campaign_on("instagram")
      linkedin = campaign_on("linkedin")
      measure(instagram, spend_minor: 45_000, impressions: 12_000, reach: 8_000, clicks: 200)
      measure(linkedin, spend_minor: 28_000, impressions: 3_000, clicks: 60)
    end

    it "sums only the platforms that report it" do
      expect(total(:reach).value).to eq(8_000)
    end

    it "names the platform that stayed silent" do
      expect(total(:reach).missing_from).to eq([ "LinkedIn" ])
      expect(total(:reach)).to be_partial
    end

    it "does not mark a figure partial when every platform reports it" do
      expect(total(:spend).missing_from).to be_empty
      expect(total(:clicks)).not_to be_partial
    end
  end

  # Reach-results and click-results are not one quantity. Adding them would
  # produce a figure that looks authoritative and means nothing.
  describe "results across different goals" do
    it "withholds the total when campaigns aim at different things" do
      reach = campaign_on("instagram", objective: "reach")
      clicks = campaign_on("facebook", objective: "traffic")
      measure(reach, results: 8_000, result_kind: "reach")
      measure(clicks, results: 120, result_kind: "link_click")

      expect(total(:results).measured?).to be(false)
      expect(total(:results).note).to include("cannot be added up")
    end

    it "shows the total, and names the goal, when they all aim at one thing" do
      first = campaign_on("instagram", objective: "reach")
      second = campaign_on("facebook", objective: "reach")
      measure(first, results: 8_000, result_kind: "reach")
      measure(second, results: 2_000, result_kind: "reach")

      expect(total(:results).value).to eq(10_000)
      expect(total(:results).note).to eq("reach")
    end
  end

  describe "what is knowable without the platform" do
    it "adds up what the owner committed, even with nothing reported" do
      campaign_on("instagram", status: "running", total_budget_minor: 500_000)
      campaign_on("facebook", status: "paused", total_budget_minor: 200_000)
      campaign_on("linkedin", status: "finished", total_budget_minor: 900_000)

      # Finished campaigns are not money still committed.
      expect(described_class.new(workspace: workspace).committed_budget.minor_units).to eq(700_000)
    end
  end

  # Spec 7.
  it "counts nothing from another workspace" do
    other = create(:workspace)
    other_post = create(:post, workspace: other)
    other_account = create(:social_account, workspace: other, provider: "instagram")
    other_campaign = create(:ad_campaign, workspace: other, post: other_post,
                                          social_account: other_account, provider: "instagram")
    measure(other_campaign, spend_minor: 999_000)

    expect(described_class.new(workspace: workspace).any_campaigns?).to be(false)
    expect(total(:spend).measured?).to be(false)
  end
end
