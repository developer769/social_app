require "rails_helper"

RSpec.describe "Home" do
  let(:owner) { create(:user, name: "Anaya Sharma") }
  let(:workspace) do
    create(:workspace, owner_user: owner, onboarding_step: "completed",
                       onboarding_completed_at: 1.week.ago)
  end

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")
  def visit_home = get workspace_root_path(**slug)

  def post_with(status, **attrs)
    p = create(:post, workspace: workspace, **attrs)
    p.update_columns(status: status)
    p
  end

  # A dashboard that opens with counts makes somebody read four numbers before
  # finding out a post failed.
  describe "what needs attention" do
    it "leads with posts that did not go out" do
      2.times { post_with("failed") }

      visit_home

      expect(body_text).to include("Needs you")
      expect(body_text).to include("2 posts did not go out")
      expect(response.body.index("Needs you")).to be < response.body.index("Went out")
    end

    it "counts a partly published post as needing attention too" do
      post_with("partially_published")

      visit_home

      expect(body_text).to include("1 post did not go out")
    end

    it "does not raise an old failure for ever" do
      p = post_with("failed")
      p.update_columns(updated_at: 40.days.ago)

      visit_home

      expect(body_text).not_to include("did not go out")
    end

    it "says which account needs reconnecting" do
      create(:social_account, workspace: workspace, provider: "instagram",
                              connection_status: "disconnected")

      visit_home

      expect(body_text).to include("Instagram needs reconnecting")
    end

    # Publishing must stop before the token dies, not when it dies.
    it "warns before a connection lapses rather than after" do
      create(:social_account, workspace: workspace, provider: "facebook",
                              token_expires_at: 3.days.from_now)

      visit_home

      expect(body_text).to include("Facebook Page expires soon")
      expect(body_text).to include("before it lapses")
    end

    it "counts people waiting for a reply" do
      account = create(:social_account, workspace: workspace, provider: "instagram")
      conversation = create(:conversation, workspace: workspace, social_account: account,
                                           provider: "instagram", last_inbound_at: 1.hour.ago)
      conversation.messages.create!(direction: "inbound", body: "Do you deliver?", sent_at: 1.hour.ago)

      visit_home

      expect(body_text).to include("1 person waiting for a reply")
    end

    it "asks for a catalog when there is none" do
      visit_home

      expect(body_text).to include("Your catalog is empty")
    end

    it "says when nothing is lined up" do
      create(:product, workspace: workspace)

      visit_home

      expect(body_text).to include("Nothing is lined up")
    end

    # A workspace still being set up has nothing scheduled and does not need
    # telling; it needs finishing setup, which it is already being told.
    it "does not nag a workspace that is still being set up" do
      workspace.update_columns(onboarding_step: "business_setup", onboarding_completed_at: nil)

      visit_home

      expect(body_text).not_to include("Nothing is lined up")
      expect(body_text).to include("Finish setting up")
    end

    it "shows nothing at all when nothing is wrong" do
      create(:product, workspace: workspace)
      create(:social_account, workspace: workspace, provider: "instagram")
      post_with("scheduled", scheduled_at: 2.days.from_now, scheduled_timezone: "Asia/Kolkata")

      visit_home

      expect(body_text).not_to include("Needs you")
    end
  end

  describe "the figures" do
    it "counts what went out, what is lined up, and what is unfinished" do
      published = post_with("published")
      published.update_columns(published_at: 3.days.ago)
      post_with("scheduled", scheduled_at: 2.days.from_now, scheduled_timezone: "Asia/Kolkata")
      post_with("draft")

      visit_home

      expect(body_text).to include("Went out").and include("Lined up").and include("In progress")
    end

    it "counts a scheduled post that is already overdue as no longer lined up" do
      post_with("scheduled", scheduled_at: 2.days.ago, scheduled_timezone: "Asia/Kolkata")

      visit_home

      # It is past its time, so it is not something still to come.
      expect(body_text).to match(/Lined up.*?0/m)
    end
  end

  describe "what is coming up" do
    it "lists the next posts with their time" do
      post_with("scheduled", caption: "Fresh truffle cakes this morning.",
                             scheduled_at: 2.days.from_now, scheduled_timezone: "Asia/Kolkata")

      visit_home

      expect(body_text).to include("Coming up")
      expect(body_text).to include("Fresh truffle cakes this morning.")
    end

    it "says a reminder post will be a reminder" do
      post_with("scheduled", caption: "A reminder post", publish_mode: "reminder",
                             scheduled_at: 1.day.from_now, scheduled_timezone: "Asia/Kolkata")

      visit_home

      expect(body_text).to include("you will be reminded to post it")
    end

    it "offers unfinished drafts a way back in" do
      post_with("draft", caption: "Half-written thought")

      visit_home

      expect(body_text).to include("Unfinished drafts")
      expect(body_text).to include("Half-written thought")
    end
  end

  # Spec 27, on the screen people open most.
  it "says the connected accounts are simulated" do
    create(:social_account, workspace: workspace, provider: "instagram")

    visit_home

    expect(body_text).to include("These are simulated")
    expect(body_text).to include("cannot post to them or read figures from them yet")
  end

  it "shows no platform figure anywhere" do
    visit_home

    expect(response.body).not_to match(/\b(followers|impressions|engagement rate|reach)\b\s*[:0-9]/i)
  end

  it "shows what has been happening lately" do
    AuditEvent.record!(action: "brand_kit.updated", workspace: workspace, actor_user: owner)

    visit_home

    expect(body_text).to include("Lately")
    expect(body_text).to include("updated the brand kit")
  end

  # Spec 7.
  describe "tenant isolation" do
    it "counts nothing from another workspace" do
      other = create(:workspace)
      other_post = create(:post, workspace: other, caption: "Someone else's post")
      other_post.update_columns(status: "failed")

      visit_home

      expect(body_text).not_to include("Someone else's post")
      expect(body_text).not_to include("did not go out")
    end
  end
end
