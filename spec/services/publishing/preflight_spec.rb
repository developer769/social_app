require "rails_helper"

RSpec.describe Publishing::Preflight do
  let(:workspace) { create(:workspace) }
  let(:post) { create(:post, workspace: workspace, caption: "Fresh cakes today.") }

  def target_for(provider, **account_attrs)
    account = create(:social_account, workspace: workspace, provider: provider, **account_attrs)
    create(:post_target, post: post, social_account: account)
  end

  def attach_image
    asset = create(:media_asset, workspace: workspace)
    post.post_media.create!(media_asset: asset, position: 0)
    asset
  end

  def results = described_class.new(post.reload).call

  def messages = results.flat_map(&:issues).map(&:message)

  # The whole reason this exists: finding out at 11am is the moment a
  # scheduling tool loses its purpose.
  describe "what it catches before the time comes" do
    it "catches a caption longer than the platform allows" do
      target_for("x")
      attach_image
      post.update!(caption: "a" * 5_000)

      expect(messages.join).to match(/caption is 5,?000 characters/)
      expect(results).to all(satisfy { |r| !r.publishable? })
    end

    it "catches more hashtags than the platform allows" do
      target_for("instagram")
      attach_image
      post.update!(hashtags: Array.new(31) { |i| "tag#{i}" })

      expect(messages.join).to include("31 hashtags")
    end

    it "catches a video the platform will not take" do
      account = create(:social_account, workspace: workspace, provider: "instagram")
      create(:post_target, post: post, social_account: account)
      asset = create(:media_asset, :video, workspace: workspace, duration_ms: 300_000)
      post.post_media.create!(media_asset: asset, position: 0)

      expect(messages.join).to match(/300 seconds and this platform allows 90/)
    end

    it "catches a platform that cannot post pictures at all" do
      target_for("youtube")
      attach_image

      expect(messages.join).to include("cannot post pictures")
    end

    # Spec 30, from the useful direction: Facebook takes text without media, so
    # it must not be told it needs a picture.
    it "does not demand a picture from a platform that posts text" do
      target_for("facebook")

      expect(messages.join).not_to include("needs a picture")
    end

    it "demands a picture from a platform that cannot post text" do
      target_for("instagram")

      expect(messages.join).to include("needs a picture or a video")
    end

    it "catches a disconnected account" do
      target_for("instagram", connection_status: "disconnected")
      attach_image

      expect(messages.join).to include("is disconnected")
    end

    it "catches an expired connection" do
      target_for("instagram", token_expires_at: 1.day.ago)
      attach_image

      expect(messages.join).to include("has expired")
    end

    # Advisory, not blocking: it will still publish today.
    it "mentions a connection that expires soon without blocking the post" do
      target_for("instagram", token_expires_at: 3.days.from_now)
      attach_image

      expect(results.first.advisory.map(&:message).join).to include("expires soon")
    end
  end

  # Spec 27. A watermarked sample must never reach a real audience.
  it "refuses to publish a generated sample" do
    target_for("instagram")
    asset = create(:media_asset, workspace: workspace, origin: "generated",
                                 metadata: { "sample" => true })
    post.post_media.create!(media_asset: asset, position: 0)

    expect(messages.join).to include("watermarked sample")
  end

  it "allows a generated picture that is not a sample" do
    target_for("instagram")
    asset = create(:media_asset, workspace: workspace, origin: "generated", metadata: {})
    post.post_media.create!(media_asset: asset, position: 0)

    expect(messages.join).not_to include("watermarked sample")
  end

  # The distinction the whole scheduling decision rests on: what the owner can
  # fix, versus what only we can.
  describe "whose problem it is" do
    it "marks 'no connection built' as ours, not the owner's" do
      target_for("instagram")
      attach_image

      result = results.first
      expect(result.only_blocked_by_us?).to be(true)
      expect(result.owner_fixable).to be_empty
      expect(result.blocking.map(&:message).join).to include("Prachar cannot post to Instagram yet")
    end

    it "marks a too-long caption as the owner's to fix" do
      target_for("x")
      attach_image
      post.update!(caption: "a" * 5_000)

      result = results.first
      expect(result.only_blocked_by_us?).to be(false)
      expect(result.owner_fixable.map(&:message).join).to include("caption is")
    end
  end
end
