# Confirming an address.
#
# Reachable without signing in and without a workspace: somebody opening the
# link on their phone should not have to sign in on that phone first.
class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access

  layout "authentication"

  def show
    verification = EmailVerification.find_usable(params[:token])

    if verification.nil?
      redirect_to login_path, alert: "That link has expired or has already been used."
      return
    end

    changing = verification.for_change?
    previous = verification.user.email
    verification.confirm!

    AuditEvent.record!(action: changing ? "user.email_changed" : "user.email_confirmed",
                       actor_user: verification.user, ip_address: request.remote_ip,
                       metadata: { purpose: verification.purpose })

    # The old address is told, always. If the change was not theirs, this mail
    # is the only warning that reaches somewhere they can still read.
    UserMailer.email_changed(verification.user, previous).deliver_later if changing

    redirect_to login_path, notice: changing ?
      "Your address is now #{verification.email}. Sign in with it." :
      "Thank you. Your address is confirmed."
  end
end
