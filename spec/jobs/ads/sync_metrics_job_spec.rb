require "rails_helper"

RSpec.describe Ads::SyncMetricsJob do
  let(:workspace) { create(:workspace) }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }
  let(:campaign) do
    create(:ad_campaign, workspace: workspace, post: create(:post, workspace: workspace),
                         social_account: account, provider: "instagram",
                         starts_on: 10.days.ago.to_date)
  end

  def row(on_date: Date.current, **figures)
    SocialProvider::AdMetricDto.new(on_date: on_date, currency: "INR", **figures)
  end

  def adapter_returning(rows)
    instance_double(SocialProvider::Adapter).tap do |adapter|
      allow(adapter).to receive(:fetch_campaign_metrics).and_return(rows)
    end
  end

  it "writes a day of figures" do
    allow(SocialProvider::Registry).to receive(:for)
      .and_return(adapter_returning([ row(spend_minor: 45_000, impressions: 12_000, clicks: 200) ]))

    expect { described_class.perform_now(campaign.id) }.to change(AdMetric, :count).by(1)

    metric = AdMetric.last
    expect(metric.spend_minor).to eq(45_000)
    expect(metric.impressions).to eq(12_000)
  end

  # Platforms revise recent days as late conversions land, so the window
  # overlaps and this runs on already-seen days constantly.
  describe "running again over the same days" do
    it "corrects a day rather than adding a second copy of it" do
      allow(SocialProvider::Registry).to receive(:for)
        .and_return(adapter_returning([ row(spend_minor: 45_000) ]))
      described_class.perform_now(campaign.id)

      allow(SocialProvider::Registry).to receive(:for)
        .and_return(adapter_returning([ row(spend_minor: 52_000) ]))

      expect { described_class.perform_now(campaign.id) }.not_to change(AdMetric, :count)
      expect(AdMetric.last.spend_minor).to eq(52_000)
    end

    it "fills in a purchase figure that arrived days later" do
      allow(SocialProvider::Registry).to receive(:for)
        .and_return(adapter_returning([ row(spend_minor: 45_000) ]))
      described_class.perform_now(campaign.id)
      expect(AdMetric.last.conversion_value_minor).to be_nil

      allow(SocialProvider::Registry).to receive(:for)
        .and_return(adapter_returning([ row(spend_minor: 45_000, conversions: 3, conversion_value_minor: 180_000) ]))
      described_class.perform_now(campaign.id)

      expect(AdMetric.last.conversion_value_minor).to eq(180_000)
    end

    it "reaches back far enough to catch a revision" do
      adapter = adapter_returning([])
      allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

      described_class.perform_now(campaign.id)

      expect(adapter).to have_received(:fetch_campaign_metrics) do |campaign:, since:|
        expect(since).to be <= Date.current - 7
      end
    end
  end

  # A figure the platform did not report must stay absent. A zero here would
  # travel to a shop owner's screen as "nobody saw it" or "nothing sold".
  it "leaves an unreported figure null rather than zero" do
    allow(SocialProvider::Registry).to receive(:for)
      .and_return(adapter_returning([ row(spend_minor: 45_000, impressions: 900) ]))

    described_class.perform_now(campaign.id)

    metric = AdMetric.last
    expect(metric.reach).to be_nil
    expect(metric.conversions).to be_nil
    expect(metric.conversion_value_minor).to be_nil
  end

  # The honest "no connection has been built" refusal. Nothing to retry, and
  # nothing the owner can do about it.
  it "stays quiet when the provider cannot report anything yet" do
    expect { described_class.perform_now(campaign.id) }.not_to raise_error
    expect(AdMetric.count).to eq(0)
  end

  it "does not sync a campaign that was never started" do
    campaign.update!(status: "draft")
    adapter = adapter_returning([ row(spend_minor: 1) ])
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

    described_class.perform_now(campaign.id)

    expect(adapter).not_to have_received(:fetch_campaign_metrics)
  end

  it "survives the campaign being deleted before a worker picks it up" do
    id = campaign.id
    campaign.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end

  describe Ads::SyncAllJob do
    # A campaign closed on Tuesday can still gain a sale on Friday.
    it "keeps asking about a campaign that recently ended" do
      campaign.update!(status: "finished", ends_on: 3.days.ago.to_date)

      expect { described_class.perform_now }.to have_enqueued_job(Ads::SyncMetricsJob).with(campaign.id)
    end

    it "stops asking about one that ended long ago" do
      campaign.update!(status: "finished", starts_on: 90.days.ago.to_date,
                       ends_on: 60.days.ago.to_date)

      expect { described_class.perform_now }.not_to have_enqueued_job(Ads::SyncMetricsJob)
    end

    it "ignores drafts" do
      campaign.update!(status: "draft")

      expect { described_class.perform_now }.not_to have_enqueued_job(Ads::SyncMetricsJob)
    end
  end
end
