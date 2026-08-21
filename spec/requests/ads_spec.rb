require "rails_helper"

RSpec.describe "Ads" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  # Advertising is the one area where a confident-looking guess costs real
  # money (spec 22).
  describe "what it refuses to claim" do
    it "says plainly that ads cannot be run yet" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Prachar cannot run ads yet")
    end

    it "says why there is no forecast, rather than leaving a gap" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("You will not find estimated reach or a suggested budget")
    end

    it "shows no budget, reach or cost figure anywhere" do
      get workspace_ads_path(**slug)

      expect(response.body).not_to match(/(estimated reach|cost per click|CPC|CPM|reach of)\s*[:â‚¹0-9]/i)
      expect(response.body).not_to match(/â‚¹\s?[0-9]/)
    end
  end

  # Everything on the checklist is answered from real records.
  describe "the readiness checklist" do
    it "counts an unconnected, empty workspace as not ready" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("0 of 4 done")
      expect(body_text).to include("None of the platforms that allow advertising are connected yet")
    end

    it "counts a connected advertising account" do
      create(:social_account, workspace: workspace, provider: "instagram")

      get workspace_ads_path(**slug)

      expect(body_text).to include("Instagram connected")
    end

    # YouTube publishes no advertising API in this catalog, so connecting it
    # must not tick the box.
    it "does not count an account that cannot advertise" do
      create(:social_account, workspace: workspace, provider: "youtube")

      get workspace_ads_path(**slug)

      expect(body_text).to include("None of the platforms that allow advertising are connected yet")
    end

    it "counts the catalog" do
      create(:product, workspace: workspace)
      create(:service, workspace: workspace)

      get workspace_ads_path(**slug)

      expect(body_text).to include("2 items in your catalog")
    end

    it "counts published posts, and agrees with itself grammatically" do
      create(:post, workspace: workspace).update_columns(status: "published")

      get workspace_ads_path(**slug)

      expect(body_text).to include("1 post has gone out")
    end

    it "counts a partly published post as having gone out" do
      create(:post, workspace: workspace).update_columns(status: "partially_published")

      get workspace_ads_path(**slug)

      expect(body_text).to include("1 post has gone out")
    end

    it "says when everything on the owner's side is done" do
      create(:social_account, workspace: workspace, provider: "instagram")
      create(:brand_profile, workspace: workspace, category: "Bakery", about: "We bake cakes.")
      create(:product, workspace: workspace)
      create(:post, workspace: workspace).update_columns(status: "published")

      get workspace_ads_path(**slug)

      expect(body_text).to include("4 of 4 done")
      expect(body_text).to include("What is left is ours to build")
    end
  end

  # Spec 30. Only the platforms that genuinely sell advertising through an API.
  describe "where ads are possible" do
    it "lists the platforms that allow advertising" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("Instagram").and include("Facebook Page").and include("LinkedIn")
    end

    it "names the platforms it left out, so their absence is not an oversight" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("YouTube, TikTok and Google Business Profile are not listed")
    end

    it "marks which of them this workspace has connected" do
      create(:social_account, workspace: workspace, provider: "instagram")

      get workspace_ads_path(**slug)

      expect(body_text).to include("Connected")
      expect(body_text).to include("Not connected")
    end
  end


  describe "the performance dashboard" do
    # Not called `post`: that name is the HTTP verb in a request spec, and
    # shadowing it breaks the sign-in in the outer before block.
    let(:advertised) { create(:post, workspace: workspace) }

    def campaign_on(provider, **overrides)
      account = create(:social_account, workspace: workspace, provider: provider)
      create(:ad_campaign, workspace: workspace, post: advertised, social_account: account,
                           provider: provider, **overrides)
    end

    it "invites a first campaign when none exist" do
      get workspace_ads_path(**slug)

      expect(body_text).to include("No money has been put behind a post yet")
    end

    it "lists campaigns with what they cost, in rupees" do
      campaign = campaign_on("instagram", name: "Diwali hampers boost", total_budget_minor: 500_000)
      create(:ad_metric, ad_campaign: campaign, spend_minor: 378_000)

      get workspace_ads_path(**slug)

      expect(body_text).to include("Diwali hampers boost")
      expect(body_text).to include("₹5,000")
      expect(body_text).to include("₹3,780")
    end

    # The measured-vs-unavailable rule, on the screen rather than in the query.
    it "says a figure was not reported rather than showing a zero" do
      campaign_on("instagram")

      get workspace_ads_path(**slug)

      expect(body_text).to include("Not reported")
      expect(body_text).not_to match(/People reached\s*<\/dt>\s*<dd[^>]*>\s*0/)
    end

    it "names a platform that does not report a figure" do
      instagram = campaign_on("instagram")
      linkedin = campaign_on("linkedin")
      create(:ad_metric, ad_campaign: instagram, reach: 8_000, spend_minor: 45_000)
      create(:ad_metric, ad_campaign: linkedin, spend_minor: 28_000)

      get workspace_ads_path(**slug)

      expect(body_text).to include("LinkedIn does not report this")
    end

    # Paid and organic reach measure different audiences that overlap by an
    # unknown amount. Adding them gives a number that means nothing.
    it "warns against reading these together with Analytics" do
      campaign_on("instagram")

      get workspace_ads_path(**slug)

      expect(body_text).to include("kept apart from Analytics on purpose")
      expect(body_text).to include("adding them together would give a number that means nothing")
    end

    it "refuses to add results across campaigns aiming at different things" do
      reach = campaign_on("instagram", objective: "reach")
      traffic = campaign_on("facebook", objective: "traffic")
      create(:ad_metric, ad_campaign: reach, results: 8_000, result_kind: "reach")
      create(:ad_metric, ad_campaign: traffic, results: 120, result_kind: "link_click")

      get workspace_ads_path(**slug)

      expect(body_text).to include("Not comparable")
      expect(body_text).to include("cannot be added up")
    end
  end

  # Spec 7.
  it "counts nothing from another workspace" do
    other = create(:workspace)
    create(:social_account, workspace: other, provider: "instagram")
    create(:product, workspace: other)

    get workspace_ads_path(**slug)

    expect(body_text).to include("0 of 4 done")
  end
end
