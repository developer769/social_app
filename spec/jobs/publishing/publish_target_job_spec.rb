require "rails_helper"

RSpec.describe Publishing::PublishTargetJob do
  include ActiveJob::TestHelper

  let(:workspace) { create(:workspace) }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }
  let(:post) { create(:post, workspace: workspace, status: "publishing") }
  let!(:target) { create(:post_target, post: post, social_account: account) }

  # Spec 34: no live API is ever called from a test. This stands in for a
  # contracted provider so the success path is exercised rather than assumed.
  def live_adapter(publication = nil)
    instance_double(SocialProvider::Adapter).tap do |adapter|
      allow(adapter).to receive(:publish).and_return(
        publication || SocialProvider::PublicationDto.new(
          remote_post_id: "IG_123", permalink: "https://instagram.com/p/IG_123", raw: { "ok" => true }
        )
      )
    end
  end

  def stub_provider(adapter)
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)
  end

  def failing_with(error)
    instance_double(SocialProvider::Adapter).tap { |a| allow(a).to receive(:publish).and_raise(error) }
  end

  describe "when the platform accepts it" do
    before { stub_provider(live_adapter) }

    it "records where it landed, so it can be found again" do
      described_class.perform_now(target.id)

      expect(target.reload).to be_published
      expect(target.remote_post_id).to eq("IG_123")
      expect(target.permalink).to eq("https://instagram.com/p/IG_123")
      expect(target.published_at).to be_present
    end

    it "settles the post once every platform has finished" do
      described_class.perform_now(target.id)

      expect(post.reload).to be_published
    end
  end

  # The worst thing this system could do is put the same post in front of a
  # customer's followers twice.
  describe "never publishing twice" do
    it "does nothing when the job is redelivered" do
      adapter = live_adapter
      stub_provider(adapter)

      described_class.perform_now(target.id)
      described_class.perform_now(target.id)

      expect(adapter).to have_received(:publish).once
    end

    it "refuses a second worker that was handed the same target" do
      # The first worker has claimed it and is mid-publish. Checking the status
      # and then publishing would let this one through.
      target.claim_for_publishing!
      adapter = live_adapter
      stub_provider(adapter)

      described_class.perform_now(target.id)

      expect(adapter).not_to have_received(:publish)
      expect(target.reload).to be_publishing
    end

    # ...but a worker killed mid-publish must not strand the post for ever.
    it "takes over a claim that has gone stale" do
      target.claim_for_publishing!
      target.update_columns(last_attempt_at: 20.minutes.ago)
      stub_provider(live_adapter)

      described_class.perform_now(target.id)

      expect(target.reload).to be_published
    end

    it "sends the same idempotency key on every attempt" do
      adapter = live_adapter
      stub_provider(adapter)
      key = target.idempotency_key

      described_class.perform_now(target.id)

      expect(adapter).to have_received(:publish).with(
        having_attributes(idempotency_key: key)
      )
    end
  end

  describe "when the platform refuses" do
    before do
      stub_provider(failing_with(SocialProvider::PermanentError.new("Caption too long", code: "invalid_caption")))
    end

    it "records why and does not try again" do
      expect { described_class.perform_now(target.id) }.not_to raise_error

      expect(target.reload).to be_failed
      expect(target.error_message).to eq("Caption too long")
      expect(target.error_code).to eq("invalid_caption")
    end

    it "settles the post as failed when nothing landed" do
      described_class.perform_now(target.id)

      expect(post.reload).to be_failed
    end
  end

  describe "when the platform is briefly unreachable" do
    before { stub_provider(failing_with(SocialProvider::TransientError.new("timeout"))) }

    # The same lesson as generation: marking it failed here would make
    # `finished?` true, and #perform returns early on a finished target -- so
    # every retry would be a no-op and one timeout would be permanent.
    it "stays retryable rather than failing on the first timeout" do
      described_class.perform_now(target.id)

      expect(target.reload).not_to be_finished
      expect(post.reload).to be_publishing
    end

    it "asks to be run again" do
      expect { described_class.perform_now(target.id) }.to have_enqueued_job(described_class)
    end

    it "gives up only once the attempts are spent" do
      perform_enqueued_jobs { described_class.perform_later(target.id) }

      expect(target.reload).to be_failed
      expect(target.error_code).to eq("provider_unavailable")
      expect(post.reload).to be_failed
    end
  end

  # Platforms answer with an opaque error when a daily cap is hit. Counting our
  # own publishes turns that into a sentence the owner can act on.
  describe "the platform's daily cap" do
    it "stops before the call and says when to try instead" do
      limit = account.capabilities.daily_publish_limit
      limit.times do |i|
        other = create(:post, workspace: workspace)
        create(:post_target, post: other, social_account: account,
                             status: "published", published_at: (i + 1).minutes.ago)
      end
      adapter = live_adapter
      stub_provider(adapter)

      described_class.perform_now(target.id)

      expect(adapter).not_to have_received(:publish)
      expect(target.reload).to be_skipped
      expect(target.error_message).to include("Schedule this for tomorrow")
    end
  end

  it "survives the target being deleted before a worker picks it up" do
    id = target.id
    target.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end
end
