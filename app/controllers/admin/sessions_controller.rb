module Admin
  class SessionsController < BaseController
    allow_unauthenticated_staff_access only: %i[new create]

    layout "admin_authentication"

    def new
      redirect_to admin_templates_path and return if resume_staff_session
    end

    def create
      staff_user = StaffUser.active.find_by(email: params[:email])

      if staff_user&.authenticate(params[:password])
        start_staff_session_for(staff_user)
        record_staff_event("staff.signed_in")
        redirect_to admin_templates_path
      else
        # Identical response whether the address is unknown, the password is
        # wrong, or the account is deactivated.
        StaffAuditEvent.record!(
          action: "staff.sign_in_failed",
          metadata: { email_hint: EmailHint.mask(params[:email]) },
          ip_address: request.remote_ip
        )
        flash.now[:alert] = "That email and password do not match."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      record_staff_event("staff.signed_out")
      terminate_staff_session
      redirect_to admin_login_path, notice: "Signed out."
    end
  end
end
