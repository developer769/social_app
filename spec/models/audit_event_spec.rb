require "rails_helper"

RSpec.describe AuditEvent do
  it "records an event against a workspace and actor" do
    membership = create(:workspace_membership)

    event = described_class.record!(
      action: "workspace_membership.invited",
      workspace: membership.workspace,
      actor_user: membership.workspace.owner_user,
      auditable: membership,
      metadata: { invitation_email: "teammate@anayabakes.test" }
    )

    expect(event.auditable).to eq(membership)
    expect(event.metadata).to eq("invitation_email" => "teammate@anayabakes.test")
  end

  it "is append-only" do
    event = described_class.record!(action: "user.signed_in")

    expect { event.update!(action: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
