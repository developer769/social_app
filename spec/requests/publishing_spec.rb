require "rails_helper"

RSpec.describe "Publishing" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }
  # The time is set by the editor before the schedule button is pressed, so a
  # draft arriving here already has one.
  let(:draft) do
    create(:post, workspace: workspace, caption: "Fresh cakes today.",
                  scheduled_at: 2.hours.from_now, scheduled_timezone: "Asia/Kolkata")
  end

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  def with_image(post)
    post.post_media.create!(media_asset: create(:media_asset, workspace: workspace), position: 0)
    post
  end

  def targeting(post, account)
    create(:post_target, post: post, social_account: account)
    post
  end

  describe "committing a post to a time" do
    before { targeting(with_image(draft), account) }

    # Nothing is connected, so this is the honest outcome rather than a refusal
    # or a false promise.
    it "schedules as a reminder and says so plainly" do
      patch schedule_workspace_post_path(**slug, id: draft), params: { post: {} }

      expect(draft.reload).to be_scheduled
      expect(draft).to be_publish_reminder
      expect(flash[:notice]).to include("Prachar cannot post there yet")
      expect(flash[:notice]).to include("reminder")
    end

    it "refuses a time that has already passed" do
      draft.update_columns(scheduled_at: 2.hours.ago)

      patch schedule_workspace_post_path(**slug, id: draft)

      expect(draft.reload).not_to be_scheduled
      expect(flash[:alert]).to include("already passed")
    end

    it "asks for a time before scheduling" do
      draft.update_columns(scheduled_at: nil)

      patch schedule_workspace_post_path(**slug, id: draft)

      expect(flash[:alert]).to include("Choose a date and time")
    end

    it "asks for somewhere to post it" do
      draft.post_targets.destroy_all

      patch schedule_workspace_post_path(**slug, id: draft)

      expect(flash[:alert]).to include("at least one account")
    end

    # The point of preflight: told now, in the owner's words, not at 11am.
    it "refuses what the owner can still fix, and says exactly what" do
      draft.update!(caption: "a" * 3_000)
      create(:post_target, post: draft, social_account: create(:social_account, workspace: workspace, provider: "x"))

      patch schedule_workspace_post_path(**slug, id: draft)

      expect(draft.reload).not_to be_scheduled
      expect(flash[:alert]).to match(/caption is 3,?000 characters/)
    end
  end

  describe "the post's own screen" do
    before { targeting(with_image(draft), account) }

    it "says where it is going and what is stopping it" do
      get workspace_post_path(**slug, id: draft)

      expect(response.body).to include("Instagram")
      expect(response.body).to include("Prachar cannot post to Instagram yet")
    end

    # Spec 27. This is the sentence that stops somebody assuming it went out.
    it "explains a reminder post before any badge can be misread" do
      draft.update!(publish_mode: "reminder", status: "scheduled",
                    scheduled_at: 1.hour.from_now, scheduled_timezone: workspace.timezone)

      get workspace_post_path(**slug, id: draft)

      expect(response.body).to include("Prachar will remind you to post this")
      expect(response.body).not_to include("Published")
    end

    it "shows where a published post landed" do
      draft.post_targets.first.mark_published!(remote_post_id: "IG_1",
                                               permalink: "https://instagram.com/p/IG_1")
      draft.update_columns(status: "published", published_at: Time.current)

      get workspace_post_path(**slug, id: draft)

      expect(response.body).to include("https://instagram.com/p/IG_1")
      expect(response.body).to include("Posted")
    end

    # A post that went to two of three platforms must say so, rather than
    # claiming it all went out or that none of it did.
    it "distinguishes a partly published post from a published one" do
      other = create(:social_account, workspace: workspace, provider: "facebook")
      create(:post_target, post: draft, social_account: other)
      draft.post_targets.first.mark_published!(remote_post_id: "IG_1")
      draft.post_targets.last.mark_failed!(code: "refused", message: "Facebook said no.")
      draft.update_columns(status: "partially_published")

      get workspace_post_path(**slug, id: draft)

      expect(response.body).to include("Partly published")
      expect(response.body).to include("Facebook said no.")
    end

    it "does not offer to edit a post that has already gone out" do
      draft.update_columns(status: "published")

      get workspace_post_path(**slug, id: draft)

      expect(response.body).not_to include("Cancel this post")
    end
  end

  # Spec 7.
  describe "tenant isolation" do
    it "cannot open another workspace's post" do
      theirs = create(:post, workspace: create(:workspace))

      get workspace_post_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot schedule another workspace's post" do
      other_workspace = create(:workspace)
      theirs = create(:post, workspace: other_workspace, scheduled_at: 1.hour.from_now)

      patch schedule_workspace_post_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).not_to be_scheduled
    end
  end
end
