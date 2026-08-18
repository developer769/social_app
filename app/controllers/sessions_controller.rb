class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  layout "authentication"

  def new
    redirect_to default_post_authentication_url and return if resume_session
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      start_new_session_for(user)
      AuditEvent.record!(action: "user.signed_in", actor_user: user, ip_address: request.remote_ip)
      redirect_to after_authentication_url
    else
      # Deliberately does not say which of the two was wrong: that difference
      # tells an attacker which addresses have accounts.
      AuditEvent.record!(action: "user.sign_in_failed", metadata: { email: params[:email].to_s.first(120) }, ip_address: request.remote_ip)
      flash.now[:alert] = "That email and password do not match."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    AuditEvent.record!(action: "user.signed_out", actor_user: current_user, ip_address: request.remote_ip)
    terminate_session
    redirect_to login_path, notice: "You have been signed out."
  end
end
