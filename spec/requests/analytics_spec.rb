require "rails_helper"

RSpec.describe "Analytics" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  # Sentences in the view wrap across lines, so a literal match against the
  # rendered HTML breaks on whitespace that means nothing to a reader.
  def body_text = response.body.gsub(/\s+/, " ")

  def post_that(status, target_status: nil, error: nil, subject: nil, at: 2.days.ago)
    post = create(:post, workspace: workspace, subject: subject)
    post.update_columns(status: status, created_at: at, published_at: (at if status == "published"),
                        reminded_at: (at if status == "reminded"))
    target = create(:post_target, post: post, social_account: account)
    target.update_columns(status: target_status || "published", error_message: error,
                          created_at: at, published_at: (at if target_status == "published"))
    post
  end

  it "counts what actually happened, from real records" do
    post_that("published")
    post_that("reminded", target_status: "skipped", error: "Prachar cannot post to Instagram yet.")
    post_that("failed", target_status: "failed", error: "Caption too long")

    get workspace_analytics_path(**slug)

    expect(response.body).to include("Went out").and include("You were reminded").and include("Did not go out")
    expect(response.body).to include("Where your posts went")
  end

  # Spec 22 and 27, and the whole reason this page needed care. A page headed
  # "Analytics" sets an expectation of likes and reach, and there are none.
  describe "what it refuses to claim" do
    before { post_that("published") }

    it "says up front that these are its own records, not platform figures" do
      get workspace_analytics_path(**slug)

      expect(body_text).to include("Prachar's own records, not platform figures")
    end

    it "names engagement as unavailable rather than showing it as zero" do
      get workspace_analytics_path(**slug)

      expect(response.body).to include("Likes, reach and followers")
      expect(response.body).to include("Not available")
      expect(response.body).to include("rather than showing you a zero")
    end

    # Specific, not a shrug: it names the platforms the figures would come from.
    it "names which platforms the missing figures would come from" do
      get workspace_analytics_path(**slug)

      expect(body_text).to include("Prachar has no connection to Instagram")
    end

    it "shows no engagement figure anywhere" do
      get workspace_analytics_path(**slug)

      expect(response.body).not_to match(/\b(impressions|reach|engagement rate)\b:?\s*[0-9]/i)
    end
  end

  describe "the posting rhythm" do
    before { create(:posting_preference, workspace: workspace, posts_per_week: 3) }

    # Telling somebody who started on Monday that they average 0.0 posts a week
    # is arithmetically true and completely useless.
    it "passes no judgement until a full week has finished" do
      3.times { post_that("published", at: 1.hour.ago) }

      get workspace_analytics_path(**slug)

      expect(response.body).to include("Not enough weeks yet")
      expect(response.body).not_to include("posting less often than you planned")
    end

    it "compares against the target once there is a finished week to compare" do
      4.times { post_that("published", at: 10.days.ago) }

      get workspace_analytics_path(**slug)

      expect(body_text).to include("Over whole weeks you have averaged")
      expect(body_text).to include("posting less often than you planned")
    end

    it "says so when the target is being met" do
      # Enough in every finished week of the window to clear three a week.
      (1..4).each { |week| 4.times { post_that("published", at: (week * 7).days.ago) } }

      get workspace_analytics_path(**slug)

      expect(body_text).to include("keeping up with what you set out to do")
    end

    it "asks for a target when none is set" do
      workspace.posting_preference.destroy!

      post_that("published")
      get workspace_analytics_path(**slug)

      expect(response.body).to include("Set a target under Posting preferences")
    end
  end

  # Entirely ours to know, and genuinely useful: a shop with eleven products
  # that has only ever posted about two can be told so.
  describe "what has been featured" do
    it "lists catalog items no post has ever featured" do
      featured = create(:product, workspace: workspace, name: "Chocolate Truffle Cake")
      create(:product, workspace: workspace, name: "Cardamom Shortbread")
      post_that("published", subject: featured)

      get workspace_analytics_path(**slug)

      expect(response.body).to include("Never posted about")
      expect(response.body).to include("Cardamom Shortbread")
    end

    it "says nothing about never-featured items when everything has been featured" do
      only = create(:product, workspace: workspace, name: "Chocolate Truffle Cake")
      post_that("published", subject: only)

      get workspace_analytics_path(**slug)

      expect(response.body).not_to include("Never posted about")
    end
  end

  it "groups what stopped posts going out, most common first" do
    2.times { post_that("failed", target_status: "failed", error: "Caption too long") }
    post_that("failed", target_status: "failed", error: "The connection expired")

    get workspace_analytics_path(**slug)

    expect(response.body).to include("What stopped things going out")
    expect(response.body).to include("Caption too long")
    expect(response.body.index("Caption too long")).to be < response.body.index("The connection expired")
  end

  it "offers a way in when nothing has happened yet" do
    get workspace_analytics_path(**slug)

    expect(response.body).to include("Nothing to report yet")
  end

  it "reads a different window when asked" do
    post_that("published", at: 60.days.ago)

    get workspace_analytics_path(**slug, days: 30)
    expect(response.body).to include("Nothing to report yet")

    get workspace_analytics_path(**slug, days: 90)
    expect(response.body).to include("Where your posts went")
  end

  it "ignores a nonsense window rather than failing" do
    post_that("published")

    get workspace_analytics_path(**slug, days: "9999999")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("last 30 days")
  end

  # Spec 7.
  it "counts nothing from another workspace" do
    other = create(:workspace)
    other_post = create(:post, workspace: other)
    other_post.update_columns(status: "published", published_at: 1.day.ago)
    create(:post_target, post: other_post,
                         social_account: create(:social_account, workspace: other, provider: "linkedin"))

    get workspace_analytics_path(**slug)

    expect(response.body).to include("Nothing to report yet")
    expect(response.body).not_to include("LinkedIn")
  end
end
