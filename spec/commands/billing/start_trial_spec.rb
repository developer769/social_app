require "rails_helper"

RSpec.describe Billing::StartTrial do
  let(:workspace) { create(:workspace, onboarding_step: "plan") }
  let(:actor) { workspace.owner_user }
  let(:plan) { create(:plan, :pro) }

  it "starts a trial on the chosen plan" do
    result = described_class.call(workspace: workspace, plan: plan, actor: actor)

    expect(result).to be_success
    subscription = result.value
    expect(subscription.plan).to eq(plan)
    expect(subscription).to be_trialing
    expect(subscription.trial_ends_at).to be_within(1.minute).of(plan.trial_days.days.from_now)
  end

  it "takes no payment and records no provider, because none is connected" do
    subscription = described_class.call(workspace: workspace, plan: plan, actor: actor).value

    expect(subscription.provider).to be_nil
    expect(subscription.provider_subscription_id).to be_nil
  end

  it "completes onboarding" do
    described_class.call(workspace: workspace, plan: plan, actor: actor)

    expect(workspace.reload.onboarding_step).to eq("completed")
    expect(workspace.onboarding_completed_at).to be_present
  end

  it "does not reset the completion timestamp when the plan is changed later" do
    described_class.call(workspace: workspace, plan: plan, actor: actor)
    originally_completed_at = workspace.reload.onboarding_completed_at

    described_class.call(workspace: workspace, plan: create(:plan, :basic), actor: actor)

    expect(workspace.reload.onboarding_completed_at).to eq(originally_completed_at)
  end

  it "replaces the existing subscription rather than creating a second one" do
    described_class.call(workspace: workspace, plan: plan, actor: actor)
    basic = create(:plan, :basic)

    expect { described_class.call(workspace: workspace, plan: basic, actor: actor) }
      .not_to change(Subscription, :count)

    expect(workspace.reload.subscription.plan).to eq(basic)
  end

  it "records an audit event naming the plan" do
    expect { described_class.call(workspace: workspace, plan: plan, actor: actor) }
      .to change { AuditEvent.where(action: "subscription.trial_started").count }.by(1)

    expect(AuditEvent.last.metadata["plan"]).to eq(plan.code)
  end

  it "refuses an inactive plan" do
    retired = create(:plan, :basic, active: false)

    result = described_class.call(workspace: workspace, plan: retired, actor: actor)

    expect(result).to be_failure
    expect(result.error).to eq(:plan_unavailable)
    expect(workspace.reload.onboarding_step).to eq("plan")
  end

  it "refuses a missing plan" do
    expect(described_class.call(workspace: workspace, plan: nil, actor: actor)).to be_failure
  end

  it "sets an annual period for an annual plan" do
    annual = create(:plan, :pro, interval: "year")

    subscription = described_class.call(workspace: workspace, plan: annual, actor: actor).value

    expect(subscription.current_period_end).to be_within(1.day).of(1.year.from_now)
  end
end
