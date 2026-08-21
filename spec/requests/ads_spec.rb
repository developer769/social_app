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

  # Spec 7.
  it "counts nothing from another workspace" do
    other = create(:workspace)
    create(:social_account, workspace: other, provider: "instagram")
    create(:product, workspace: other)

    get workspace_ads_path(**slug)

    expect(body_text).to include("0 of 4 done")
  end
end
