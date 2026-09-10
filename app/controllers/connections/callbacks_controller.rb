module Connections
  # Receives the owner back from the platform.
  #
  # Not workspace-scoped, and it cannot be: every platform requires the
  # redirect URI to be a single fixed string registered in advance, so there is
  # no slug in this path. The workspace is read from the session that
  # AuthorizationsController wrote, and membership is re-checked here rather
  # than trusted -- the session says which workspace was intended, not that the
  # person is still allowed into it.
  class CallbacksController < ApplicationController
    SESSION_KEY = AuthorizationsController::SESSION_KEY

    # This request arrives from the platform's domain, so it carries no CSRF
    # token. The `state` value checked in CompleteAuthorization is what
    # protects it, and for this flow it is the stronger of the two: it proves
    # the round trip started here, which a session token alone would not.
    skip_before_action :verify_authenticity_token

    def show
      pending = session.delete(SESSION_KEY) # single use, whatever happens next

      if expired?(pending)
        return redirect_to(root_path, alert: "That connection attempt expired. Please start again.")
      end

      workspace = Workspace.find_by(id: pending["workspace_id"])
      membership = workspace && current_user.accepted_memberships.find_by(workspace: workspace)

      # Identical wording whether the workspace is gone or was never theirs, so
      # this reveals nothing about workspaces they cannot see (spec 7).
      if membership.nil?
        return redirect_to(root_path, alert: "That workspace is no longer available.")
      end

      back = workspace_settings_connections_path(workspace_slug: workspace.slug)

      # Platforms report refusal in the query string, not by status code.
      return redirect_to(back, alert: denial_message) if params[:error].present?

      result = CompleteAuthorization.call(
        workspace: workspace,
        provider: pending["provider"],
        actor: current_user,
        code: params[:code],
        state: params[:state],
        expected_state: pending["state"],
        verifier: pending["verifier"],
        host: request.host_with_port
      )

      if result.success?
        account = result.value
        redirect_to back, notice: "#{account.provider_name} connected as #{account.handle}."
      else
        redirect_to back, alert: failure_message(result.error)
      end
    end

    private

    def expired?(pending)
      return true if pending.blank? || pending["expires_at"].blank?

      Time.iso8601(pending["expires_at"]) <= Time.current
    rescue ArgumentError
      true
    end

    def denial_message
      case params[:error].to_s
      when "access_denied", "user_denied", "user_cancelled_login", "user_cancelled_authorize"
        "That connection was cancelled, so nothing changed."
      else
        # The platform's own description is usually more specific than anything
        # this application could infer.
        params[:error_description].presence || "The platform refused that connection."
      end
    end

    def failure_message(error)
      case error
      when :invalid_state
        "That connection could not be verified, so it was refused. Please start again from Settings."
      when :no_code          then "The platform did not send anything back. Please try again."
      when :not_configured   then "That platform has not been set up with API credentials yet."
      when :unknown_provider then "That platform is not supported."
      when SocialProvider::PermanentError then error.message
      when SocialProvider::TransientError then "#{error.message} Please try again shortly."
      else "That account could not be connected."
      end
    end
  end
end
