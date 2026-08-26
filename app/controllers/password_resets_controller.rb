# Getting back in.
#
# Every path through here answers the same way whether or not the address has
# an account. A form that says "no such user" is a way of finding out who is
# registered, and this one is reachable without signing in (spec 13).
class PasswordResetsController < ApplicationController
  allow_unauthenticated_access

  layout "authentication"

  SAME_ANSWER = "If that address has an account, a link to set a new password is on its way. " \
                "It works for two hours.".freeze

  def new; end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    reset = PasswordReset.issue!(user: user, ip: request.remote_ip)

    UserMailer.password_reset(reset.user, reset.raw_token).deliver_later if reset

    AuditEvent.record!(
      action: "user.password_reset_requested", actor_user: user, ip_address: request.remote_ip,
      # The address is never stored in the clear here: a masked hint and a
      # stable digest are enough to spot one account being hammered.
      metadata: { email_hint: EmailHint.mask(params[:email]),
                  email_digest: EmailHint.digest(params[:email]) }
    )

    redirect_to login_path, notice: SAME_ANSWER
  end

  def edit
    @reset = PasswordReset.find_usable(params[:token])
    @token = params[:token]

    redirect_to new_password_reset_path, alert: expired_message and return if @reset.nil?
  end

  def update
    @token = params[:token]
    @reset = PasswordReset.find_usable(@token)

    redirect_to new_password_reset_path, alert: expired_message and return if @reset.nil?

    user = @reset.user
    if user.update(password: params.dig(:user, :password))
      finish(user)
    else
      @user_errors = user.errors
      render :edit, status: :unprocessable_content
    end
  end

  private

  def finish(user)
    @reset.consume!(ip: request.remote_ip)

    # Everything that was signed in with the old password is signed out. A
    # password reset is what somebody does when they think another person has
    # their account, and leaving those sessions alive would defeat the point.
    revoked = Session.where(user: user).where(revoked_at: nil).update_all(revoked_at: Time.current)

    AuditEvent.record!(action: "user.password_reset_completed", actor_user: user,
                       ip_address: request.remote_ip, metadata: { sessions_revoked: revoked })

    UserMailer.password_changed(user).deliver_later

    start_new_session_for(user)
    redirect_to after_authentication_url, notice: "Your password has been changed. You are signed in."
  end

  def expired_message
    "That link has expired or has already been used. Ask for a new one."
  end
end
