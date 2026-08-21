require "rails_helper"

# Prachar cannot measure revenue on its own, but a business that HAS put a
# pixel on a website can say so. These are the three genuinely different
# situations, and collapsing them into "no revenue" would misdescribe two.
RSpec.describe "Ad conversion tracking" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  let(:advertised) { create(:post, workspace: workspace) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def account_for(provider = "instagram", **attrs)
    create(:social_account, workspace: workspace, provider: provider, **attrs)
  end

  def campaign_for(account, **overrides)
    create(:ad_campaign, workspace: workspace, post: advertised, social_account: account,
                         provider: account.provider, **overrides)
  end

  describe "nothing is watching" do
    before { create(:ad_metric, ad_campaign: campaign_for(account_for), spend_minor: 225_000) }

    it "explains that this is about measurement, not about the ads" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Not tracked")
      expect(body_text).to include("it means nothing was measuring")
    end

    # The point of this whole change: open to it for those who do have one.
    it "offers a way in for a business that does have a pixel" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("I have a Meta Pixel or a conversion tag")
    end
  end

  describe "a pixel is connected but nothing has come back" do
    before do
      account = account_for("instagram", conversion_tracking_id: "1234567890123456",
                                         conversion_tracking_added_at: Time.current)
      create(:ad_metric, ad_campaign: campaign_for(account), spend_minor: 225_000)
    end

    # Saying "nothing was measuring" here would be wrong, and would send
    # somebody off to fix something they have already done.
    it "does not tell them nothing is measuring" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Waiting for figures")
      expect(body_text).to include("set up to report purchases")
      expect(body_text).not_to include("it means nothing was measuring")
    end

    it "explains the delay rather than leaving it blank" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Figures usually arrive a day behind")
    end

    it "does not offer to add a pixel that is already added" do
      get workspace_ads_path(**slug)

      expect(body_text).not_to include("I have a Meta Pixel or a conversion tag")
      expect(body_text).to include("Reading purchases from Instagram (1234567890123456)")
    end
  end

  describe "figures have arrived" do
    before do
      account = account_for("instagram", conversion_tracking_id: "1234567890123456")
      create(:ad_metric, ad_campaign: campaign_for(account), spend_minor: 100_000,
                         conversions: 12, conversion_value_minor: 340_000)
    end

    it "shows the platform's own revenue and return" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Tracked")
      expect(body_text).to include("₹3,400")
      expect(body_text).to include("from 12 tracked purchases")
      expect(body_text).to include("3.4&times;")
      expect(body_text).to include("by the platform's own count")
    end
  end

  describe "recording a pixel" do
    it "saves it and says what will happen next" do
      account = account_for("instagram")
      campaign_for(account)

      patch workspace_ads_tracking_path(**slug), params: { tracking: { account.id.to_s => "1234567890123456" } }

      expect(account.reload.conversion_tracking_id).to eq("1234567890123456")
      expect(account.conversion_tracking_added_at).to be_present
      expect(flash[:notice]).to include("usually arrive a day behind")
    end

    it "trims what was pasted in" do
      account = account_for("instagram")

      patch workspace_ads_tracking_path(**slug), params: { tracking: { account.id.to_s => "  9876543210  " } }

      expect(account.reload.conversion_tracking_id).to eq("9876543210")
    end

    it "clears it when emptied" do
      account = account_for("instagram", conversion_tracking_id: "1234567890123456",
                                         conversion_tracking_added_at: Time.current)

      patch workspace_ads_tracking_path(**slug), params: { tracking: { account.id.to_s => "" } }

      expect(account.reload.conversion_tracking_id).to be_nil
      expect(account.conversion_tracking_added_at).to be_nil
    end

    it "records the change so it is answerable later" do
      account = account_for("instagram")

      expect { patch workspace_ads_tracking_path(**slug), params: { tracking: { account.id.to_s => "111222333" } } }
        .to change { AuditEvent.where(action: "ad_tracking.updated").count }.by(1)
    end

    # Spec 7.
    it "cannot set a pixel on another workspace's account" do
      other = create(:workspace)
      theirs = create(:social_account, workspace: other, provider: "instagram")

      patch workspace_ads_tracking_path(**slug), params: { tracking: { theirs.id.to_s => "999" } }

      expect(theirs.reload.conversion_tracking_id).to be_nil
    end
  end

  # Spec 30. Requesting conversion metrics with no dataset behind them is an
  # error on every real ad API, so the question is not asked at all.
  describe "whether purchase figures are even requested" do
    it "does not ask a platform with no pixel configured" do
      account = account_for("instagram")

      adapter = SocialProvider::Registry.for("instagram", account: account)
      expect(adapter.revenue_readable?(account)).to be(false)
    end

    it "asks once a pixel is configured" do
      account = account_for("instagram", conversion_tracking_id: "1234567890123456")

      adapter = SocialProvider::Registry.for("instagram", account: account)
      expect(adapter.revenue_readable?(account)).to be(true)
    end

    # YouTube sells no advertising in this catalog, so a pixel on it would be
    # meaningless.
    it "never asks a platform that reports no purchase value" do
      account = account_for("youtube", conversion_tracking_id: "1234567890123456")

      adapter = SocialProvider::Registry.for("youtube", account: account)
      expect(adapter.revenue_readable?(account)).to be(false)
    end
  end
end
