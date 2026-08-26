module Settings
  # Changing the address on the account, and re-sending the confirmation for
  # one nobody has proved yet.
  class EmailAddressController < BaseController
  # Asking to move to a new address. Nothing is written to the account here:
  # the new address is proved first (see EmailVerification#confirm!).
  def create
    unless current_user.authenticate(params.dig(:user, :current_password).to_s)
      return redirect_to security_path, alert: "That is not your current password."
    end

    email = params.dig(:user, :email).to_s.strip.downcase

    if (problem = malformed(email))
      return redirect_to security_path, alert: problem
    end

    # An address already in use gets the SAME answer as a free one, and no mail
    # is sent. Saying "that is taken" would turn this form into a way of
    # finding out who is registered (spec 13).
    if User.where.not(id: current_user.id).exists?(email: email)
      return redirect_to security_path, notice: sent_notice(email)
    end

    verification = EmailVerification.issue!(user: current_user, email: email,
                                            purpose: "change", ip: request.remote_ip)
    return redirect_to security_path, alert: "Too many requests. Try again in an hour." if verification.nil?

    UserMailer.confirm_email(current_user, verification.email, verification.raw_token,
                             purpose: "change").deliver_later
    # The address they can still read is told that a move was asked for, so a
    # change they did not make is visible while it can still be stopped.
    UserMailer.email_change_requested(current_user, email).deliver_later

    redirect_to security_path, notice: sent_notice(email)
  end

  # Sending the signup confirmation again, for anyone whose first one was lost.
  def resend
    verification = EmailVerification.issue!(user: current_user, email: current_user.email,
                                            purpose: "signup", ip: request.remote_ip)

    if verification
      UserMailer.confirm_email(current_user, verification.email, verification.raw_token,
                               purpose: "signup").deliver_later
      redirect_to security_path, notice: "Sent. Check #{current_user.email}."
    else
      redirect_to security_path, alert: "Too many requests. Try again in an hour."
    end
  end

  private

  def security_path
    workspace_settings_security_path(workspace_slug: current_workspace.slug)
  end

  # Only shapes a person can see for themselves. Anything about who else
  # holds an address is answered identically in create.
  def malformed(email)
    return "Enter an email address." if email.blank?
    return "That is not an email address." unless email.match?(URI::MailTo::EMAIL_REGEXP)

    "That is already your address." if email == current_user.email
  end

  def sent_notice(email)
    "Check #{email} for a link. Your address changes only once you have opened it."
  end

  def confirmation_notice(changing, email)
    changing ? "Your address is now #{email}. Sign in with it." : "Thank you. Your address is confirmed."
  end
  end
end
