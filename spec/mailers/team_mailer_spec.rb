require "rails_helper"

RSpec.describe TeamMailer do
  let(:workspace) { create(:workspace, name: "Anaya Bakes") }
  let(:membership) do
    create(:workspace_membership, :pending, workspace: workspace,
           invitation_email: "teammate@example.test", invited_by: workspace.owner_user)
  end

  def invitation
    membership.issue_invitation!(invited_by: workspace.owner_user)
    described_class.invitation(membership, membership.raw_invitation_token)
  end

  # Rails ships a placeholder sender that receiving servers reject. Shipping
  # with it would mean no invitation ever arrived.
  it "does not send from the Rails placeholder address" do
    expect(invitation.from.first).not_to include("example.com")
  end

  it "sends from a configured address" do
    expect(invitation.from).to be_present
    expect(invitation.reply_to).to be_present
  end

  it "is addressed to the person invited" do
    expect(invitation.to).to eq([ "teammate@example.test" ])
  end

  it "names who invited them and which business" do
    expect(invitation.subject).to include(workspace.owner_user.name)
    expect(invitation.subject).to include("Anaya Bakes")
  end

  it "carries a working acceptance link" do
    membership.issue_invitation!(invited_by: workspace.owner_user)
    token = membership.raw_invitation_token
    mail = described_class.invitation(membership, token)

    expect(mail.body.encoded).to include(token)
  end

  it "offers both an HTML and a plain text part, since not every client renders HTML" do
    expect(invitation.body.parts.map(&:content_type).join).to include("text/plain", "text/html")
  end

  it "says when the invitation expires" do
    expect(invitation.body.encoded).to match(/expires/i)
  end
end
