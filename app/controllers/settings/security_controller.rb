module Settings
  class SecurityController < BaseController
    def show
      load_sessions
    end

    def update
      unless current_user.authenticate(params.dig(:user, :current_password).to_s)
        flash.now[:alert] = "That is not your current password."
        load_sessions
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
        load_sessions
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

    # Everything except the device being used to ask. Someone who has lost a
    # phone should not have to work out which of nine identical-looking rows it
    # is -- and being signed out of the device you are holding, mid-panic, is
    # the opposite of what was wanted.
    def revoke_other_sessions
      count = other_sessions.update_all(revoked_at: Time.current)

      AuditEvent.record!(action: "user.other_sessions_revoked", workspace: current_workspace,
                         actor_user: current_user, ip_address: request.remote_ip,
                         metadata: { count: count })

      redirect_to workspace_settings_security_path(**slug),
                  notice: count.zero? ? "You are not signed in anywhere else." :
                          "Signed out of #{helpers.pluralize(count, 'other device')}. You are still signed in here."
    end

    private

    SHOWN = 8

    # The current device first, then the rest newest-first, capped. Ordering by
    # created_at alone buried "this device" among identical-looking rows.
    def load_sessions
      active = current_user.sessions.active.order(created_at: :desc).to_a
      current, others = active.partition { |record| record.id == Current.session&.id }

      @sessions = (current + others).first(SHOWN)
      @other_session_count = others.size
      @hidden_session_count = [ active.size - SHOWN, 0 ].max
    end

    def other_sessions
      current_user.sessions.active.where.not(id: Current.session&.id)
    end
  end
end
