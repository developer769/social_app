require "rails_helper"

# There was no posts list at all: GET /posts/new existed and GET /posts did
# not. A draft with no date is invisible on the calendar, so a post could be
# created and then genuinely lost.
RSpec.describe "The posts list" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def post_with(status, caption: "A post", **attrs)
    record = create(:post, workspace: workspace, caption: caption, **attrs)
    record.update_columns(status: status)
    record
  end

  describe "what it shows by default" do
    it "leads with what has been left half done" do
      post_with("draft", caption: "Half written")
      post_with("scheduled", caption: "Ready to go", scheduled_at: 2.days.from_now,
                             scheduled_timezone: "Asia/Kolkata")

      get workspace_posts_path(**slug)

      expect(body_text).to include("Half written")
      expect(body_text).not_to include("Ready to go")
    end

    # The whole reason this page exists.
    it "shows a draft that has no date, which the calendar cannot" do
      post_with("draft", caption: "Nowhere to be found", scheduled_at: nil)

      get workspace_posts_path(**slug)

      expect(body_text).to include("Nowhere to be found")
      expect(body_text).to include("No date yet")
    end

    it "counts each group so nothing hides behind a tab" do
      post_with("draft")
      post_with("failed")
      2.times { post_with("published") }

      get workspace_posts_path(**slug)

      expect(@response.body).to include("Needs you")
      expect(body_text).to match(/Went out\s*<[^>]*>\s*2/)
    end

    it "treats a partly published post as needing you" do
      post_with("partially_published", caption: "Two of three")

      get workspace_posts_path(**slug)

      expect(body_text).to include("Two of three")
    end
  end

  describe "the other groups" do
    before do
      post_with("draft", caption: "Draft one")
      post_with("scheduled", caption: "Coming soon", scheduled_at: 2.days.from_now,
                             scheduled_timezone: "Asia/Kolkata")
      post_with("published", caption: "Already out")
    end

    it "shows what is coming up" do
      get workspace_posts_path(**slug, group: "in_flight")

      expect(body_text).to include("Coming soon")
      expect(body_text).not_to include("Draft one")
    end

    it "shows what has gone out" do
      get workspace_posts_path(**slug, group: "settled")

      expect(body_text).to include("Already out")
      expect(body_text).not_to include("Coming soon")
    end

    it "shows everything at once" do
      get workspace_posts_path(**slug, group: "all")

      expect(body_text).to include("Draft one").and include("Coming soon").and include("Already out")
    end

    it "ignores a group nobody has heard of" do
      get workspace_posts_path(**slug, group: "nonsense")

      expect(response).to have_http_status(:ok)
      expect(body_text).to include("Draft one")
    end
  end

  describe "searching" do
    before do
      post_with("draft", caption: "Chocolate truffle cake, fresh today")
      post_with("draft", caption: "Almond biscotti")
    end

    it "finds a post by its words" do
      get workspace_posts_path(**slug, q: "truffle")

      expect(body_text).to include("Chocolate truffle")
      expect(body_text).not_to include("Almond biscotti")
    end

    it "does not care about case" do
      get workspace_posts_path(**slug, q: "CHOCOLATE")

      expect(body_text).to include("Chocolate truffle")
    end

    it "finds a post by its hashtags" do
      post_with("draft", caption: "Festival offer", hashtags: %w[Diwali Mithai])

      get workspace_posts_path(**slug, q: "diwali")

      expect(body_text).to include("Festival offer")
    end

    # A search term is user input going into a LIKE pattern.
    it "treats a wildcard as a literal character" do
      get workspace_posts_path(**slug, q: "%")

      expect(response).to have_http_status(:ok)
      expect(body_text).not_to include("Almond biscotti")
    end

    it "says what matched nothing, rather than looking empty" do
      get workspace_posts_path(**slug, q: "samosa")

      expect(body_text).to include("Nothing matched &quot;samosa&quot;")
    end
  end

  # Repeating a post is the commonest thing a shop does with one, and it used
  # to mean retyping it.
  describe "copying a post" do
    let(:account) { create(:social_account, workspace: workspace) }
    let(:product) { create(:product, workspace: workspace) }
    let!(:original) do
      original = create(:post, workspace: workspace, caption: "Weekend special",
                               hashtags: %w[AnayaBakes Weekend], subject: product,
                               first_comment: "Order on WhatsApp", link_url: "https://example.test",
                               scheduled_at: 2.days.from_now, scheduled_timezone: "Asia/Kolkata")
      create(:post_target, post: original, social_account: account)
      original.post_media.create!(media_asset: create(:media_asset, workspace: workspace), position: 0)
      original.update_columns(status: "published", published_at: 1.day.ago)
      original
    end

    it "copies the words, the picture, what it features and where it goes" do
      expect { post duplicate_workspace_post_path(**slug, id: original) }
        .to change(Post, :count).by(1)

      copy = Post.order(:id).last
      expect(copy.caption).to eq("Weekend special")
      expect(copy.hashtags).to eq(%w[AnayaBakes Weekend])
      expect(copy.subject).to eq(product)
      expect(copy.first_comment).to eq("Order on WhatsApp")
      expect(copy.post_media.first.media_asset).to eq(original.post_media.first.media_asset)
      expect(copy.post_targets.map(&:social_account)).to eq([ account ])
    end

    # A duplicate is a starting point, not a scheduled twin.
    it "copies nothing about what already happened to the original" do
      post duplicate_workspace_post_path(**slug, id: original)

      copy = Post.order(:id).last
      expect(copy).to be_draft
      expect(copy.scheduled_at).to be_nil
      expect(copy.published_at).to be_nil
    end

    # Two posts can share a picture; they must never share an idempotency key,
    # or a copy could reach a provider as a retry of the original.
    it "gives the copy its own idempotency key" do
      post duplicate_workspace_post_path(**slug, id: original)

      copy = Post.order(:id).last
      expect(copy.post_targets.first.idempotency_key)
        .not_to eq(original.post_targets.first.idempotency_key)
    end

    it "opens the copy for editing and says it has no date" do
      post duplicate_workspace_post_path(**slug, id: original)

      copy = Post.order(:id).last
      expect(response).to redirect_to(edit_workspace_post_path(**slug, id: copy))
      expect(flash[:notice]).to include("no date yet")
    end

    it "records it, so two near-identical posts can be explained later" do
      expect { post duplicate_workspace_post_path(**slug, id: original) }
        .to change { AuditEvent.where(action: "post.duplicated").count }.by(1)
    end
  end

  # Spec 7.
  describe "tenant isolation" do
    it "lists nothing from another workspace" do
      other = create(:workspace)
      create(:post, workspace: other, caption: "Somebody else's post")
        .update_columns(status: "draft")

      get workspace_posts_path(**slug, group: "all")

      expect(body_text).not_to include("Somebody else's post")
    end

    it "cannot copy another workspace's post" do
      other = create(:workspace)
      theirs = create(:post, workspace: other, caption: "Not yours")

      expect { post duplicate_workspace_post_path(**slug, id: theirs) }.not_to change(Post, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
