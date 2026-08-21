require "rails_helper"

RSpec.describe Generation::RunOutputJob do
  include ActiveJob::TestHelper

  let(:workspace) { create(:workspace) }
  let(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }
  let(:post) { create(:post, workspace: workspace, template: create(:template), subject: product) }
  let(:request) { create(:creative_request, :with_outputs, workspace: workspace, post: post) }
  let(:output) { request.creative_outputs.order(:position).first }

  def stub_provider(adapter)
    allow(CreativeProvider::Registry).to receive(:for).and_return(adapter)
  end

  def failing_with(error)
    instance_double(CreativeProvider::MockAdapter).tap do |adapter|
      allow(adapter).to receive(:generate).and_raise(error)
    end
  end

  describe "a variant that works" do
    it "attaches a real file and marks the row ready" do
      described_class.perform_now(output.id)

      expect(output.reload).to be_ready
      expect(output.media_asset.file).to be_attached
      expect(output.media_asset.origin).to eq("generated")
    end

    # Spec 27. The asset itself must carry the flag, because publishing checks
    # the asset and never the request it came from.
    it "records the asset as a sample" do
      described_class.perform_now(output.id)

      expect(output.reload.media_asset.metadata["sample"]).to be(true)
      expect(output).to be_sample
    end
  end

  # A real provider charges per call, so a Sidekiq retry landing on finished
  # work must not spend a second generation.
  it "does nothing when run again on a finished variant" do
    described_class.perform_now(output.id)
    asset_id = output.reload.media_asset_id

    expect { described_class.perform_now(output.id) }.not_to change(MediaAsset, :count)
    expect(output.reload.media_asset_id).to eq(asset_id)
  end

  it "survives the row being deleted before the worker picks it up" do
    id = output.id
    output.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end

  describe "when the provider refuses" do
    before { stub_provider(failing_with(CreativeProvider::PermanentError.new("no", code: "safety"))) }

    it "records the refusal and does not retry it" do
      expect { described_class.perform_now(output.id) }.not_to raise_error

      expect(output.reload).to be_failed
      expect(output.outcome).to eq("refused")
    end

    it "explains a refusal differently from a provider being down" do
      described_class.perform_now(output.id)

      expect(output.reload.failure_label).to eq("The generator would not make this one")
    end
  end

  describe "when the provider is temporarily down" do
    before { stub_provider(failing_with(CreativeProvider::TransientError.new("timeout"))) }

    # The row was previously marked failed here AND the error re-raised for a
    # retry -- but a failed row is finished, and #perform returns early on a
    # finished output, so every retry was a no-op and the first blip was
    # permanent.
    it "leaves the variant retryable rather than settling it on the first blip" do
      expect { described_class.perform_later(output.id) && perform_enqueued_jobs(only: described_class) { } }
        .not_to raise_error

      described_class.perform_now(output.id)

      expect(output.reload).not_to be_finished
      expect(output).to be_generating
    end

    it "asks to be run again rather than giving up" do
      expect { described_class.perform_now(output.id) }.to have_enqueued_job(described_class)
    end

    it "still generates when a later attempt succeeds" do
      described_class.perform_now(output.id)
      stub_provider(CreativeProvider::MockAdapter.new)

      described_class.perform_now(output.id)

      expect(output.reload).to be_ready
      expect(output.media_asset.file).to be_attached
    end

    # Only once the attempts are genuinely spent does the row settle, so the
    # screen can stop saying "making your pictures".
    it "records a provider problem once the attempts are spent" do
      perform_enqueued_jobs { described_class.perform_later(output.id) }

      expect(output.reload).to be_failed
      expect(output.outcome).to eq("provider_error")
      expect(output.failure_label).to eq("The generator had a problem")
    end
  end

  describe "settling the parent" do
    it "leaves the request generating until every variant has finished" do
      described_class.perform_now(output.id)

      expect(request.reload).to be_generating
      expect(request.finished_count).to eq(1)
    end

    it "marks the request ready once they all succeed" do
      request.creative_outputs.each { |o| described_class.perform_now(o.id) }

      expect(request.reload).to be_ready
      expect(request.ready_count).to eq(3)
    end

    # One good picture out of three is still a usable result, and saying
    # "failed" would throw it away.
    it "marks the request partially ready when some variants fail" do
      described_class.perform_now(output.id)
      request.creative_outputs.where.not(id: output.id).each do |other|
        other.fail!(outcome: "refused", message: "no")
      end
      request.reload.settle!

      expect(request.reload).to be_partially_ready
      expect(request.usable_outputs.size).to eq(1)
    end

    it "marks the request failed only when nothing could be made" do
      stub_provider(failing_with(CreativeProvider::PermanentError.new("no", code: "safety")))
      request.creative_outputs.each { |o| described_class.perform_now(o.id) }

      expect(request.reload).to be_failed
    end
  end

  # Live updating is a convenience. Losing it must never undo a generation that
  # actually succeeded.
  it "keeps a generated variant when the live update cannot be sent" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_raise(StandardError, "redis down")

    expect { described_class.perform_now(output.id) }.not_to raise_error
    expect(output.reload).to be_ready
  end
end
