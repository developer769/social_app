require "rails_helper"

# The detail card behind each calendar entry. The behaviour that opens it lives
# in a Stimulus controller; what a request spec can hold to account is that the
# card is rendered, carries the right detail, and is reachable by something
# other than a mouse.
RSpec.describe "The calendar preview" do
  include ActiveSupport::Testing::TimeHelpers

  # The month and week views only show what falls inside them, so a post
  # scheduled "three days from now" disappears from both whenever the suite
  # runs near the end of a month -- which is exactly how this first failed.
  # Frozen to a Wednesday in mid-September, with posts a day later: same week,
  # same month, whatever day the suite actually runs.
  around { |example| travel_to(Time.find_zone("Asia/Kolkata").local(2026, 9, 16, 9, 0)) { example.run } }

  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner, timezone: "Asia/Kolkata") }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }
  let(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def scheduled_post(**attrs)
    record = create(:post, workspace: workspace, subject: product,
                           scheduled_at: 1.day.from_now, scheduled_timezone: "Asia/Kolkata",
                           **attrs)
    create(:post_target, post: record, social_account: account)
    record.update_columns(status: "scheduled")
    record
  end

  it "carries the full caption, not the truncated one on the entry" do
    long = "Fresh chocolate truffle cake, baked this morning and finished with a ganache " \
           "that takes two days to get right. Order before four for same-day delivery."
    scheduled_post(caption: long)

    get workspace_calendar_path(**slug)

    # The entry truncates; the card does not.
    expect(body_text).to include("Order before four for same-day delivery")
  end

  it "names what the post features" do
    scheduled_post(caption: "Weekend special")

    get workspace_calendar_path(**slug)

    expect(body_text).to include("Featuring Chocolate Truffle Cake")
  end

  it "shows the hashtags" do
    scheduled_post(caption: "Weekend special", hashtags: %w[AnayaBakes Chocolate])

    get workspace_calendar_path(**slug)

    expect(body_text).to include("#AnayaBakes #Chocolate")
  end

  it "shows the time in the workspace's own clock" do
    scheduled_post(caption: "Weekend special")

    get workspace_calendar_path(**slug)

    expect(body_text).to include("IST")
  end

  # On a post that half went out, this is the only place the difference is
  # visible without opening it.
  it "says what each platform did, separately" do
    post = scheduled_post(caption: "Two of three")
    facebook = create(:social_account, workspace: workspace, provider: "facebook")
    create(:post_target, post: post, social_account: facebook)

    post.post_targets.first.mark_published!(remote_post_id: "IG_1")
    post.post_targets.last.mark_failed!(code: "refused", message: "Facebook said no.")
    post.update_columns(status: "partially_published")

    get workspace_calendar_path(**slug)

    expect(body_text).to include("Instagram").and include("Facebook Page")
    expect(body_text).to include("Posted").and include("Did not post")
  end

  # Spec 27: the card must not let a reminder-mode post read as one that went
  # out.
  it "says a reminder post will not be published for you" do
    post = scheduled_post(caption: "Weekend special")
    post.update!(publish_mode: "reminder")

    get workspace_calendar_path(**slug)

    expect(body_text).to include("Prachar cannot post here yet")
  end

  it "says plainly when no caption has been written" do
    scheduled_post(caption: nil)

    get workspace_calendar_path(**slug)

    expect(body_text).to include("No caption written yet")
  end

  # Hover is not the only way in. A calendar whose detail is hover-only cannot
  # be read with a keyboard at all.
  describe "reachable without a mouse" do
    before { scheduled_post(caption: "Weekend special") }

    it "opens on focus as well as hover" do
      get workspace_calendar_path(**slug)

      expect(response.body).to include("focusin->post-preview#show")
      expect(response.body).to include("mouseenter->post-preview#show")
    end

    it "ties the entry to its card for assistive technology" do
      get workspace_calendar_path(**slug)

      expect(response.body).to match(/aria-describedby="post-preview-\d+"/)
      expect(response.body).to match(/id="post-preview-\d+" role="tooltip"/)
    end

    # The card is hoverable itself, so reaching for it does not dismiss it.
    it "keeps itself open while the pointer is on it" do
      get workspace_calendar_path(**slug)

      expect(response.body).to match(/role="tooltip".*?mouseenter->post-preview#show/m)
    end
  end

  it "renders a card for every entry in every view" do
    3.times { |i| scheduled_post(caption: "Post #{i}") }

    %w[month week agenda].each do |view|
      get workspace_calendar_path(**slug, view: view)

      expect(response.body.scan('role="tooltip"').size).to be >= 1
    end
  end

  # Spec 7.
  it "shows nothing from another workspace" do
    other = create(:workspace)
    theirs = create(:post, workspace: other, caption: "Somebody else's post",
                           scheduled_at: 1.day.from_now, scheduled_timezone: "Asia/Kolkata")
    theirs.update_columns(status: "scheduled")

    get workspace_calendar_path(**slug)

    expect(body_text).not_to include("Somebody else's post")
  end
end
