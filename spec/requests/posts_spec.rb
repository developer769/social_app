require "rails_helper"

RSpec.describe "Posts and the calendar" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner, timezone: "Asia/Kolkata") }
  let(:zone) { ActiveSupport::TimeZone["Asia/Kolkata"] }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  def connect(provider)
    Connections::ConnectAccount.call(workspace: workspace, provider: provider, actor: owner).value
  end

  describe "creating a post" do
    it "schedules it to the chosen accounts" do
      instagram = connect("instagram")
      facebook = connect("facebook")

      post workspace_posts_path(**slug), params: {
        post: { caption: "Fresh out of the oven.", hashtags: "#AnayaBakes #Chocolate",
                status: "scheduled", scheduled_date: (zone.today + 2).to_s, scheduled_time: "10:30" },
        social_account_ids: [ instagram.id, facebook.id ]
      }

      created = workspace.posts.sole
      expect(created).to be_scheduled
      expect(created.hashtags).to eq(%w[AnayaBakes Chocolate])
      expect(created.post_targets.map(&:provider)).to contain_exactly("instagram", "facebook")
      expect(response).to redirect_to(workspace_calendar_path(**slug))
    end

    it "records the time in the workspace's own zone" do
      connect("instagram")

      post workspace_posts_path(**slug), params: {
        post: { caption: "Evening treat.", status: "scheduled",
                scheduled_date: "2026-09-10", scheduled_time: "23:45" },
        social_account_ids: [ workspace.social_accounts.first.id ]
      }

      created = workspace.posts.sole
      expect(created.scheduled_timezone).to eq("Asia/Kolkata")
      expect(created.scheduled_at_local.strftime("%Y-%m-%d %H:%M")).to eq("2026-09-10 23:45")
    end

    # Scheduling with no date would create a post the scheduler can never find.
    it "saves as a draft when no date was given, rather than a scheduled post with no slot" do
      post workspace_posts_path(**slug), params: {
        post: { caption: "No date yet.", status: "scheduled" }
      }

      expect(workspace.posts.sole).to be_draft
    end

    it "gives each target a distinct idempotency key so a retry cannot double publish" do
      connect("instagram")
      connect("facebook")

      post workspace_posts_path(**slug), params: {
        post: { caption: "Two places.", status: "draft" },
        social_account_ids: workspace.social_accounts.pluck(:id)
      }

      keys = workspace.posts.sole.post_targets.pluck(:idempotency_key)
      expect(keys.uniq.size).to eq(2)
      expect(keys).to all(be_present)
    end
  end

  describe "platform capability" do
    # Google Business Profile cannot accept video. Offering it and failing at
    # publish time would waste the owner's slot (spec 30).
    it "refuses to target a platform that cannot carry the media" do
      google = connect("google_business")
      instagram = connect("instagram")

      video = create(:media_asset, :video, workspace: workspace)
      created = create(:post, workspace: workspace)
      created.post_media.create!(media_asset: video, position: 0)

      patch workspace_post_path(**slug, id: created), params: {
        post: { caption: "A reel." },
        social_account_ids: [ google.id, instagram.id ]
      }

      expect(created.post_targets.reload.map(&:provider)).to contain_exactly("instagram")
    end

    it "explains on the form why an account is unavailable" do
      connect("google_business")
      video = create(:media_asset, :video, workspace: workspace)
      created = create(:post, workspace: workspace)
      created.post_media.create!(media_asset: video, position: 0)

      get edit_workspace_post_path(**slug, id: created)

      expect(response.body).to include("cannot post video")
    end
  end

  describe "the calendar" do
    it "shows a scheduled post" do
      create(:post, workspace: workspace, status: "scheduled",
             caption: "Weekend special", scheduled_at: zone.now + 2.days,
             scheduled_timezone: "Asia/Kolkata")

      get workspace_calendar_path(**slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weekend special")
    end

    it "offers a way to start when nothing is scheduled" do
      get workspace_calendar_path(**slug)

      expect(response.body).to include("Create your first post")
    end

    # The design shows specific best-posting windows "based on your audience
    # activity". None exists yet, so the panel must not invent any.
    it "shows no invented best-posting times" do
      connect("instagram")

      get workspace_calendar_path(**slug)

      expect(response.body).to include("Best time to post")
      expect(response.body).to include("simulated")
      expect(response.body).not_to match(/10:00 AM\s*[–-]\s*12:00 PM/)
    end

    it "renders every view" do
      %w[month week day agenda].each do |view|
        get workspace_calendar_path(**slug, view: view)
        expect(response).to have_http_status(:ok), "#{view} view failed"
      end
    end
  end

  describe "changing a schedule" do
    let(:scheduled) do
      create(:post, workspace: workspace, status: "scheduled",
             scheduled_at: zone.now + 2.days, scheduled_timezone: "Asia/Kolkata")
    end

    it "moves back to draft so it will not publish" do
      patch unschedule_workspace_post_path(**slug, id: scheduled)

      expect(scheduled.reload).to be_draft
    end

    it "cancels without deleting" do
      post cancel_workspace_post_path(**slug, id: scheduled)

      expect(scheduled.reload).to be_cancelled
      expect(Post.exists?(scheduled.id)).to be(true)
    end
  end

  describe "tenant isolation" do
    let(:other) { create(:workspace) }

    before { create(:workspace_membership, workspace: other, user: create(:user)) }

    it "cannot open another workspace's calendar" do
      get workspace_calendar_path(workspace_slug: other.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot edit another workspace's post" do
      theirs = create(:post, workspace: other, caption: "Not yours")

      get edit_workspace_post_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
    end
  end
end
