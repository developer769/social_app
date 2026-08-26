require "rails_helper"

# There was no way to do this at all. Somebody who forgot their password was
# locked out of their own business permanently: no route, no mailer, and no
# link on the sign-in page.
RSpec.describe "Resetting a forgotten password" do
  include ActiveJob::TestHelper

  let!(:user) { create(:user, email: "anaya@anayabakes.test") }

  def body_text = response.body.gsub(/\s+/, " ")

  # These mails are multipart, so body.to_s is empty -- the content lives in
  # the html and text parts.
  def mail_body(mail)
    # decoded, not to_s: quoted-printable wraps long lines with soft breaks,
    # which splits a reset URL in half and makes the token unfindable.
    [ mail.html_part, mail.text_part ].compact.map { |part| part.body.decoded }.join("
")
  end

  it "is offered on the sign-in page, where somebody stuck will be looking" do
    get login_path

    expect(response.body).to include("Forgotten your password?")
    expect(response.body).to include(new_password_reset_path)
  end

  describe "asking for a link" do
    it "sends one" do
      expect {
        perform_enqueued_jobs { post password_resets_path, params: { email: user.email } }
      }.to change(PasswordReset, :count).by(1)

      expect(ActionMailer::Base.deliveries.last.to).to eq([ user.email ])
    end

    # A form that says "no such user" is a way of finding out who is
    # registered, so both answers are identical (spec 13).
    it "answers an unknown address exactly as it answers a real one" do
      post password_resets_path, params: { email: user.email }
      known = [ response.status, flash[:notice] ]

      post password_resets_path, params: { email: "nobody@example.test" }

      expect([ response.status, flash[:notice] ]).to eq(known)
    end

    it "creates nothing for an address with no account" do
      expect {
        post password_resets_path, params: { email: "nobody@example.test" }
      }.not_to change(PasswordReset, :count)
    end

    # A reset link is a live credential sitting in an inbox.
    it "stores only a digest, never the token itself" do
      perform_enqueued_jobs { post password_resets_path, params: { email: user.email } }

      link = mail_body(ActionMailer::Base.deliveries.last)[%r{password/edit\?token=([\w-]+)}, 1]
      expect(link).to be_present
      expect(PasswordReset.last.token_digest).not_to eq(link)
      expect(PasswordReset.find_usable(link)).to eq(PasswordReset.last)
    end

    # The link in the email was dead once: deliver_later reloads the record
    # through GlobalID, and only the digest is stored, so the raw token did not
    # survive the queue. Asserting a mail was sent would not have caught it --
    # this follows the link.
    it "sends a link that actually works" do
      perform_enqueued_jobs { post password_resets_path, params: { email: user.email } }

      token = mail_body(ActionMailer::Base.deliveries.last)[%r{password/edit\?token=([\w-]+)}, 1]
      expect(token).to be_present

      get edit_password_reset_path(token: token)
      expect(response).to have_http_status(:ok)

      patch password_reset_path, params: { token: token, user: { password: "a-brand-new-secret" } }
      expect(user.reload.authenticate("a-brand-new-secret")).to be_truthy
    end

    it "will not be used to fill somebody's inbox" do
      6.times { post password_resets_path, params: { email: user.email } }

      expect(PasswordReset.where(user: user).count).to eq(PasswordReset::MAX_PER_HOUR)
    end

    it "records the request without writing the address down in the clear" do
      expect {
        post password_resets_path, params: { email: user.email }
      }.to change { AuditEvent.where(action: "user.password_reset_requested").count }.by(1)

      expect(AuditEvent.last.metadata["email_hint"]).not_to eq(user.email)
      expect(AuditEvent.last.metadata["email_digest"]).to be_present
    end
  end

  describe "using the link" do
    let(:reset) { PasswordReset.issue!(user: user) }

    it "sets the new password and signs them in" do
      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "a-brand-new-secret" } }

      expect(user.reload.authenticate("a-brand-new-secret")).to be_truthy
      expect(response).to redirect_to(after_authentication_url_for(user))
    end

    # A reset is what somebody does when they think another person has their
    # account. Leaving those sessions alive would defeat the whole point.
    it "signs out everything that was signed in with the old password" do
      old = Session.start!(user: user)

      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "a-brand-new-secret" } }

      expect(old.reload.revoked_at).to be_present
    end

    it "cannot be used twice" do
      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "a-brand-new-secret" } }

      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "another-attempt-here" } }

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.authenticate("another-attempt-here")).to be_falsey
    end

    # Asking twice and using the first link must not leave the second live in
    # an inbox.
    it "spends every other outstanding link for the same person" do
      second = PasswordReset.issue!(user: user)

      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "a-brand-new-secret" } }

      expect(second.reload).not_to be_usable
    end

    it "refuses one that has expired" do
      reset.update!(expires_at: 1.minute.ago)

      patch password_reset_path, params: { token: reset.raw_token,
                                           user: { password: "a-brand-new-secret" } }

      expect(response).to redirect_to(new_password_reset_path)
      expect(flash[:alert]).to include("expired")
    end

    it "refuses a token nobody issued" do
      get edit_password_reset_path(token: "not-a-real-token")

      expect(response).to redirect_to(new_password_reset_path)
    end

    it "keeps the form open when the new password is rejected" do
      patch password_reset_path, params: { token: reset.raw_token, user: { password: "short" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(reset.reload).to be_usable
    end

    # If this was not them, it is the only warning they will get.
    it "tells the address owner afterwards" do
      perform_enqueued_jobs do
        patch password_reset_path, params: { token: reset.raw_token,
                                             user: { password: "a-brand-new-secret" } }
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("password was changed")
      expect(mail_body(mail)).to include("If this was not you")
    end

    it "warns before they commit that other devices will be signed out" do
      get edit_password_reset_path(token: reset.raw_token)

      expect(body_text).to include("signs you out everywhere else")
    end
  end

  # A helper mirroring the app's own post-authentication redirect, so this spec
  # does not hard-code a path that lives in one place.
  def after_authentication_url_for(user)
    Workspaces::LandingPath.new(user: user).call
  end
end
