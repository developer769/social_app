require "rails_helper"

RSpec.describe "Gallery" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "what a customer can see" do
    # Drafts and retired styles are staff concerns. Neither may ever reach a
    # customer's gallery.
    it "shows only published, live styles" do
      published = create(:template, name: "Published Style")
      create(:template, name: "Draft Style", draft: true, published_at: nil)
      create(:template, :retired, name: "Retired Style")

      get workspace_gallery_path(**slug)

      expect(response.body).to include(published.name)
      expect(response.body).not_to include("Draft Style")
      expect(response.body).not_to include("Retired Style")
    end

    it "opens a style's own page" do
      template = create(:template, name: "Weekend Indulgence")

      get workspace_gallery_template_path(**slug, slug: template.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weekend Indulgence")
    end

    it "refuses a style that is not published" do
      template = create(:template, draft: true, published_at: nil)

      get workspace_gallery_template_path(**slug, slug: template.slug)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "photos and videos" do
    let!(:photo) { create(:template, name: "A Photo Style") }
    let!(:video) { create(:template, :video, name: "A Video Style") }

    it "defaults to photos" do
      get workspace_gallery_path(**slug)

      expect(response.body).to include("A Photo Style")
      expect(response.body).not_to include("A Video Style")
    end

    it "switches to videos" do
      get workspace_gallery_path(**slug, format: "video")

      expect(response.body).to include("A Video Style")
      expect(response.body).not_to include("A Photo Style")
    end

    it "falls back to photos for a format it does not recognise" do
      get workspace_gallery_path(**slug, format: "hologram")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A Photo Style")
    end
  end

  describe "filtering and searching" do
    let!(:festive) { create(:template, name: "Diwali Sweets", content_category: "festive") }
    let!(:offer) { create(:template, name: "Weekend Deal", content_category: "offer") }

    it "narrows to a category" do
      get workspace_gallery_path(**slug, category: "festive")

      expect(response.body).to include("Diwali Sweets")
      expect(response.body).not_to include("Weekend Deal")
    end

    it "searches names and style words" do
      get workspace_gallery_path(**slug, q: "diwali")

      expect(response.body).to include("Diwali Sweets")
      expect(response.body).not_to include("Weekend Deal")
    end

    it "explains an empty result rather than showing a bare grid" do
      get workspace_gallery_path(**slug, q: "nothing matches this")

      expect(response.body).to include("No photo styles match")
      expect(response.body).to include("Clear filters")
    end

    it "only offers categories that actually contain something" do
      get workspace_gallery_path(**slug)

      expect(response.body).to include("Festive")
      expect(response.body).not_to include("Testimonials")
    end
  end

  describe "honesty about ordering" do
    # The gallery may only use the word "trending" when a source has supplied a
    # real signal. With none, it says what the order actually is (spec 27).
    it "does not claim trending when nothing has been scored" do
      create(:template, name: "Unscored")

      get workspace_gallery_path(**slug)

      expect(response.body).to include("Picked by Prachar")
      expect(response.body).not_to include("Trending now")
    end

    it "says trending once a real signal exists" do
      create(:template, :trending, name: "Scored")

      get workspace_gallery_path(**slug)

      expect(response.body).to include("Trending now")
    end
  end

  describe "tenant isolation" do
    it "cannot open another workspace's gallery" do
      other = create(:workspace)
      create(:workspace_membership, workspace: other, user: create(:user))

      get workspace_gallery_path(workspace_slug: other.slug)

      expect(response).to have_http_status(:not_found)
    end
  end
end
