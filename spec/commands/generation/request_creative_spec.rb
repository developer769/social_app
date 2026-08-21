require "rails_helper"

RSpec.describe Generation::RequestCreative do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  let(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }
  let(:template) { create(:template) }
  let(:post) { create(:post, workspace: workspace, template: template, subject: product) }

  def call(**overrides)
    described_class.call(workspace: workspace, post: post, actor: owner, **overrides)
  end

  it "creates every variant row before any job runs" do
    result = nil
    expect { result = call }.to change(CreativeOutput, :count).by(3)

    request = result.value
    expect(request.creative_outputs.map(&:position)).to eq([ 0, 1, 2 ])
    expect(request.creative_outputs.map(&:status).uniq).to eq([ "pending" ])
  end

  # Spec 24: progress must be countable from records. If the rows arrived one
  # at a time the screen would have to guess at the total.
  it "reports progress from those rows and not from elapsed time" do
    request = call.value

    expect(request.progress_percentage).to eq(0)
    request.creative_outputs.first.fail!(outcome: "refused", message: "no")
    expect(request.reload.progress_percentage).to eq(33)
  end

  it "enqueues one job per variant, after the rows are committed" do
    expect { call }.to have_enqueued_job(Generation::RunOutputJob).exactly(3).times
  end

  it "records the request in the audit trail" do
    expect { call }.to change { AuditEvent.where(action: "creative.requested").count }.by(1)
  end

  it "refuses when the post has nothing to feature" do
    post.update!(subject: nil)

    expect(call).to be_failure
    expect(call.error).to eq(:no_subject)
  end

  # Spec 30. A video template must be refused up front rather than queueing
  # three jobs that are each certain to fail.
  it "refuses video before enqueuing anything" do
    post.update!(template: create(:template, :video))

    expect { expect(call.error).to eq(:format_unsupported) }
      .not_to change(CreativeRequest, :count)
  end

  # This guard used to fall through for images: only the video arm returned, so
  # an image request against a provider that cannot make images queued work
  # that could not succeed.
  it "refuses when the provider cannot make pictures at all" do
    blind = CreativeProvider::MockAdapter.new
    allow(blind).to receive(:capabilities)
      .and_return(CreativeProvider::Capabilities.new(supports: [], limits: {}))
    allow(CreativeProvider::Registry).to receive(:default).and_return(blind)

    expect { expect(call.error).to eq(:provider_unavailable) }
      .not_to change(CreativeRequest, :count)
  end

  it "stores the provider key the registry can resolve later" do
    request = call.value

    expect { CreativeProvider::Registry.for(request.provider) }.not_to raise_error
  end
end
