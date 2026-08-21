require "rails_helper"

# Return on ad spend is the number most likely to make somebody spend more
# money. Everything here is about refusing to produce it unless it is real.
RSpec.describe "Ad revenue and return" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  # Not called `post`: that name is the HTTP verb in a request spec.
  let(:advertised) { create(:post, workspace: workspace) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def campaign_on(provider = "instagram", **overrides)
    account = create(:social_account, workspace: workspace, provider: provider)
    create(:ad_campaign, workspace: workspace, post: advertised, social_account: account,
                         provider: provider, **overrides)
  end

  describe "when the platform measured nothing" do
    let!(:campaign) { campaign_on }

    before { create(:ad_metric, ad_campaign: campaign, spend_minor: 225_000) }

    # The most important sentence on the page. A shop taking orders on WhatsApp
    # will always see this, and reading it as "the ads sold nothing" would be
    # wrong in a way that costs money.
    it "explains that nothing was watching, rather than implying nothing sold" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("That usually does not mean the ads sold nothing")
      expect(body_text).to include("it means nothing was measuring")
    end

    it "shows no measured return at all" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Not tracked")
      expect(body_text).not_to match(/0(\.0+)?&times;\s*back for every rupee/)
    end
  end

  describe "what the owner counted" do
    let!(:campaign) { campaign_on }

    before { create(:ad_metric, ad_campaign: campaign, spend_minor: 225_000) }

    it "records orders and revenue" do
      expect {
        post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: campaign),
             params: { ad_outcome: { occurred_on: Date.current, orders: 23, revenue: "2970" } }
      }.to change(AdOutcome, :count).by(1)

      outcome = AdOutcome.last
      expect(outcome.orders).to eq(23)
      expect(outcome.revenue_minor).to eq(297_000)
      expect(outcome.recorded_by).to eq(owner)
    end

    it "works out the return and the cost of an order" do
      create(:ad_outcome, ad_campaign: campaign, orders: 23, revenue_minor: 297_000)

      get workspace_ads_path(**slug)

      expect(body_text).to include("1.32&times;")
      expect(body_text).to include("by your own count")
      expect(body_text).to include("₹97.83 of advertising per order")
    end

    # Somebody will type "₹2,970" or "Rs 2970". None of those should become a
    # different number, and none should be a 500.
    it "understands an amount typed the way a person types it" do
      post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: campaign),
           params: { ad_outcome: { occurred_on: Date.current, revenue: "₹2,970" } }

      expect(AdOutcome.last.revenue_minor).to eq(297_000)
    end

    it "refuses an amount it cannot read rather than guessing at one" do
      post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: campaign),
           params: { ad_outcome: { occurred_on: Date.current, revenue: "about three thousand" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(AdOutcome.count).to eq(0)
      expect(response.body).to include("must be an amount")
    end

    it "refuses a row that records nothing" do
      post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: campaign),
           params: { ad_outcome: { occurred_on: Date.current, orders: "", revenue: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter how many orders came in")
    end

    it "refuses a day that has not happened" do
      post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: campaign),
           params: { ad_outcome: { occurred_on: 3.days.from_now.to_date, orders: 5 } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(body_text).to include("cannot be in the future")
    end

    it "says so on the form itself, so the figure is never mistaken for measurement" do
      get new_workspace_ad_campaign_outcome_path(**slug, ad_campaign_id: campaign)

      expect(body_text).to include("Prachar cannot see your sales")
      expect(body_text).to include("never as something a platform measured")
    end
  end

  # An unknown treated as zero would put a confident number about money in
  # front of somebody deciding whether to spend more of it.
  describe "when only half of it is known" do
    it "shows no return when revenue is recorded but nothing was spent" do
      campaign = campaign_on
      create(:ad_outcome, ad_campaign: campaign, orders: 10, revenue_minor: 100_000)

      get workspace_ads_path(**slug)

      expect(body_text).not_to match(/&times;\s*back for every rupee/)
      expect(body_text).to include("No spend has been reported yet")
    end

    it "shows no return when spend is known but nothing came back" do
      campaign = campaign_on
      create(:ad_metric, ad_campaign: campaign, spend_minor: 225_000)

      get workspace_ads_path(**slug)

      expect(body_text).not_to match(/&times;\s*back for every rupee/)
    end

    it "counts orders without revenue, and still refuses a return" do
      campaign = campaign_on
      create(:ad_metric, ad_campaign: campaign, spend_minor: 225_000)
      create(:ad_outcome, ad_campaign: campaign, orders: 10, revenue_minor: nil)

      get workspace_ads_path(**slug)

      expect(body_text).to include("₹225 of advertising per order")
      expect(body_text).not_to match(/&times;\s*back for every rupee/)
    end
  end

  # Two numbers of different provenance summed into one would be worth less
  # than either of them.
  describe "keeping the two sources apart" do
    it "never adds a platform figure to the owner's own" do
      campaign = campaign_on
      create(:ad_metric, ad_campaign: campaign, spend_minor: 225_000, conversion_value_minor: 150_000)
      create(:ad_outcome, ad_campaign: campaign, orders: 23, revenue_minor: 297_000)

      get workspace_ads_path(**slug)

      expect(body_text).to include("₹1,500")
      expect(body_text).to include("₹2,970")
      # The sum of the two, ₹4,470, must appear nowhere.
      expect(body_text).not_to include("₹4,470")
      expect(body_text).to include("deliberately not added together")
    end

    it "labels each return with where its revenue came from" do
      campaign = campaign_on
      create(:ad_metric, ad_campaign: campaign, spend_minor: 100_000, conversion_value_minor: 300_000)
      create(:ad_outcome, ad_campaign: campaign, revenue_minor: 500_000)

      get workspace_ads_path(**slug)

      expect(body_text).to include("by the platform's own count")
      expect(body_text).to include("by your own count")
    end
  end

  # Spec 7.
  describe "tenant isolation" do
    it "cannot record an outcome against another workspace's campaign" do
      other = create(:workspace)
      theirs = create(:ad_campaign, workspace: other, post: create(:post, workspace: other),
                                    social_account: create(:social_account, workspace: other))

      post workspace_ad_campaign_outcomes_path(**slug, ad_campaign_id: theirs),
           params: { ad_outcome: { occurred_on: Date.current, orders: 5 } }

      expect(response).to have_http_status(:not_found)
      expect(AdOutcome.count).to eq(0)
    end

    it "counts no revenue from another workspace" do
      other = create(:workspace)
      theirs = create(:ad_campaign, workspace: other, post: create(:post, workspace: other),
                                    social_account: create(:social_account, workspace: other))
      create(:ad_outcome, ad_campaign: theirs, revenue_minor: 999_000)
      campaign_on

      get workspace_ads_path(**slug)

      expect(body_text).not_to include("₹9,990")
      expect(body_text).to include("Nothing logged")
    end
  end
end
