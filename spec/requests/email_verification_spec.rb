require "rails_helper"

# Two gaps that were really one. There was no way to change an address, and
# nothing ever confirmed one -- users.confirmed_at was set by seeds and read by
# nobody. Both matter for the same reason: a password reset goes to this
# address, so an account with an address its owner cannot read has no way back
# in at all.
RSpec.describe "Confirming and changing an email address" do
  include ActiveJob::TestHelper

  let(:owner) { create(:user, email: "anaya@anayabakes.test") }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def mail_body(mail)
    [ mail.html_part, mail.text_part ].compact.map { |part| part.body.decoded }.join("\n")
  end

  def token_from(mail) = mail_body(mail)[%r{email/confirm\?token=([\w-]+)}, 1]

  describe "confirming the address on the account" do
    it "marks the account once the link is opened" do
      verification = EmailVerification.issue!(user: owner, email: owner.email, purpose: "signup")

      get email_verification_path(token: verification.raw_token)

      expect(owner.reload).to be_confirmed
    end

    it "says on the security page whether it was ever done" do
      owner.update!(confirmed_at: nil)

      get workspace_settings_security_path(**slug)

      expect(body_text).to include("Not confirmed")
      expect(body_text).to include("a password reset will never reach you")
    end

    it "sends the link again for anyone whose first one was lost" do
      owner.update!(confirmed_at: nil)

      expect {
        perform_enqueued_jobs { post workspace_settings_security_email_resend_path(**slug) }
      }.to change(EmailVerification, :count).by(1)

      expect(ActionMailer::Base.deliveries.last.to).to eq([ owner.email ])
    end

    it "refuses a link that has already been used" do
      verification = EmailVerification.issue!(user: owner, email: owner.email, purpose: "signup")
      get email_verification_path(token: verification.raw_token)

      get email_verification_path(token: verification.raw_token)

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to include("expired or has already been used")
    end

    it "refuses one that has expired" do
      verification = EmailVerification.issue!(user: owner, email: owner.email, purpose: "signup")
      verification.update!(expires_at: 1.minute.ago)

      get email_verification_path(token: verification.raw_token)

      expect(owner.reload).not_to be_confirmed
    end
  end

  describe "changing to a new address" do
    let(:params) do
      { user: { email: "new@anayabakes.test", current_password: "correct-horse-battery" } }
    end

    # Nothing is written to the account until the new address is proved. An
    # unproved address on the account would be a way to take it over, because
    # password reset goes wherever the address points.
    it "does not move the address until the new one is confirmed" do
      post workspace_settings_security_email_path(**slug), params: params

      expect(owner.reload.email).to eq("anaya@anayabakes.test")
      expect(EmailVerification.last.email).to eq("new@anayabakes.test")
    end

    it "moves it once the link is opened" do
      perform_enqueued_jobs { post workspace_settings_security_email_path(**slug), params: params }
      token = token_from(ActionMailer::Base.deliveries.find { |m| m.to == [ "new@anayabakes.test" ] })

      get email_verification_path(token: token)

      expect(owner.reload.email).to eq("new@anayabakes.test")
      expect(owner).to be_confirmed
    end

    # Re-authentication for a sensitive action: an unattended signed-in browser
    # must not be enough to walk off with the account.
    it "will not do it without the current password" do
      post workspace_settings_security_email_path(**slug),
           params: { user: { email: "new@anayabakes.test", current_password: "wrong" } }

      expect(EmailVerification.count).to eq(0)
      expect(flash[:alert]).to include("not your current password")
    end

    # Sent to the address they can still read, while it can still be stopped.
    it "warns the current address that a move was asked for" do
      perform_enqueued_jobs { post workspace_settings_security_email_path(**slug), params: params }

      warning = ActionMailer::Base.deliveries.find { |m| m.to == [ "anaya@anayabakes.test" ] }
      expect(warning.subject).to include("asked to change your")
      expect(mail_body(warning)).to include("If this was not you")
    end

    # After the fact, to the address that no longer works.
    it "tells the old address once it has moved" do
      perform_enqueued_jobs { post workspace_settings_security_email_path(**slug), params: params }
      token = token_from(ActionMailer::Base.deliveries.find { |m| m.to == [ "new@anayabakes.test" ] })

      perform_enqueued_jobs { get email_verification_path(token: token) }

      final = ActionMailer::Base.deliveries.select { |m| m.to == [ "anaya@anayabakes.test" ] }.last
      expect(final.subject).to include("address was changed")
    end

    # Saying "that is taken" would turn this form into a way of finding out who
    # is registered (spec 13).
    it "answers an address somebody else holds exactly as it answers a free one" do
      create(:user, email: "taken@example.test")

      post workspace_settings_security_email_path(**slug), params: params
      free = [ response.status, flash[:notice].sub("new@anayabakes.test", "ADDRESS") ]

      post workspace_settings_security_email_path(**slug),
           params: { user: { email: "taken@example.test", current_password: "correct-horse-battery" } }
      taken = [ response.status, flash[:notice].sub("taken@example.test", "ADDRESS") ]

      # Identical but for the address echoed back, which the person typed
      # themselves and so already knows.
      expect(taken).to eq(free)
    end

    it "sends nothing to an address somebody else holds" do
      create(:user, email: "taken@example.test")

      perform_enqueued_jobs do
        post workspace_settings_security_email_path(**slug),
             params: { user: { email: "taken@example.test", current_password: "correct-horse-battery" } }
      end

      expect(ActionMailer::Base.deliveries.map(&:to).flatten).not_to include("taken@example.test")
    end

    it "refuses something that is not an address" do
      post workspace_settings_security_email_path(**slug),
           params: { user: { email: "not an address", current_password: "correct-horse-battery" } }

      expect(flash[:alert]).to include("not an email address")
      expect(EmailVerification.count).to eq(0)
    end

    it "says so when the new address is the one already on the account" do
      post workspace_settings_security_email_path(**slug),
           params: { user: { email: owner.email, current_password: "correct-horse-battery" } }

      expect(flash[:alert]).to include("already your address")
    end

    # Asking twice and confirming the first must not leave the second live.
    it "spends every other outstanding link for the same person" do
      first = EmailVerification.issue!(user: owner, email: "a@example.test", purpose: "change")
      second = EmailVerification.issue!(user: owner, email: "b@example.test", purpose: "change")

      get email_verification_path(token: first.raw_token)

      expect(second.reload).not_to be_usable
      expect(owner.reload.email).to eq("a@example.test")
    end

    it "will not be used to fill an inbox" do
      6.times do
        post workspace_settings_security_email_path(**slug),
             params: { user: { email: "new@anayabakes.test", current_password: "correct-horse-battery" } }
      end

      expect(EmailVerification.where(user: owner).count).to eq(EmailVerification::MAX_PER_HOUR)
    end

    it "records the change so it can be explained later" do
      verification = EmailVerification.issue!(user: owner, email: "new@example.test", purpose: "change")

      expect { get email_verification_path(token: verification.raw_token) }
        .to change { AuditEvent.where(action: "user.email_changed").count }.by(1)
    end
  end

  # A reset link is a live credential; so is a confirmation link that can move
  # an address.
  it "stores only a digest, never the token" do
    verification = EmailVerification.issue!(user: owner, email: owner.email, purpose: "signup")

    expect(EmailVerification.last.token_digest).not_to eq(verification.raw_token)
    expect(EmailVerification.find_usable(verification.raw_token)).to eq(verification)
  end
end
