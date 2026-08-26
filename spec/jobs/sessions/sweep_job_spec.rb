require "rails_helper"

# Nothing removed spent sessions, so the row for every sign-in a person ever
# made lived for ever and all of them were listed. A development workspace
# reached 67 in eight days.
RSpec.describe Sessions::SweepJob do
  let(:user) { create(:user) }

  def session_row(**attrs)
    Session.create!(user: user, token_digest: SecureRandom.hex(32),
                    expires_at: 30.days.from_now, **attrs)
  end

  it "deletes a session revoked long ago" do
    old = session_row(revoked_at: 60.days.ago)

    expect { described_class.perform_now }.to change(Session, :count).by(-1)
    expect(Session.exists?(old.id)).to be(false)
  end

  it "deletes one that expired long ago" do
    session_row(expires_at: 60.days.ago)

    expect { described_class.perform_now }.to change(Session, :count).by(-1)
  end

  # Kept a little past the point of no use, so "you were signed out an hour
  # ago" is still answerable from the row itself.
  it "keeps one revoked recently" do
    session_row(revoked_at: 2.days.ago)

    expect { described_class.perform_now }.not_to change(Session, :count)
  end

  it "never touches a session still in use" do
    live = session_row

    expect { described_class.perform_now }.not_to change(Session, :count)
    expect(Session.exists?(live.id)).to be(true)
  end

  it "leaves the audit trail alone, which is where the history belongs" do
    session_row(revoked_at: 60.days.ago)
    AuditEvent.record!(action: "user.session_revoked", actor_user: user)

    expect { described_class.perform_now }.not_to change(AuditEvent, :count)
  end
end
