module Settings
  class SecurityController < BaseController
    def show
      @sessions = current_user.sessions.active.order(created_at: :desc)
    end

    def update
      unless current_user.authenticate(params.dig(:user, :current_password).to_s)
        flash.now[:alert] = "That is not your current password."
        @sessions = current_user.sessions.active.order(created_at: :desc)
        return render :show, status: :unprocessable_content
      end

      if current_user.update(password: params.dig(:user, :password))
        # Changing a password must end every other session, or a stolen one
        # survives the very act meant to stop it.
        other_sessions.update_all(revoked_at: Time.current)
        AuditEvent.record!(action: "user.password_changed", workspace: current_workspace,
                           actor_user: current_user, ip_address: request.remote_ip)
        redirect_to workspace_settings_security_path(**slug),
                    notice: "Password changed. Every other device has been signed out."
      else
        @user_errors = current_user.errors
        @sessions = current_user.sessions.active.order(created_at: :desc)
        render :show, status: :unprocessable_content
      end
    end

    def revoke_session
      session_record = current_user.sessions.find(params[:id])
      session_record.revoke!

      AuditEvent.record!(action: "user.session_revoked", workspace: current_workspace,
                         actor_user: current_user, ip_address: request.remote_ip)

      if session_record.id == Current.session&.id
        redirect_to login_path, notice: "Signed out on this device."
      else
        redirect_to workspace_settings_security_path(**slug), notice: "That device has been signed out."
      end
    end

    private

    def other_sessions
      current_user.sessions.active.where.not(id: Current.session&.id)
    end
  end
end
