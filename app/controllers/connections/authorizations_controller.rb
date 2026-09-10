module Connections
  # Sends the owner to the platform to grant access.
  #
  # This half is workspace-scoped in the usual way. The return half is not, and
  # lives in CallbacksController: every platform requires the redirect URI to
  # be one fixed string registered in advance, so the workspace cannot travel
  # in that path. It travels in the session instead -- which is also the safer
  # place for it, since the workspace a connection lands in is then decided by
  # this server rather than by whatever came back in a query string.
  class AuthorizationsController < ApplicationController
    include WorkspaceScoping

    # What the callback needs in order to trust what comes back.
    SESSION_KEY = :social_authorization

    def create
      result = StartAuthorization.call(
        workspace: current_workspace, provider: params[:provider], host: request.host_with_port
      )

      unless result.success?
        return redirect_to(
          workspace_settings_connections_path(workspace_slug: current_workspace.slug),
          alert: failure_message(result.error)
        )
      end

      auth = result.value
      session[SESSION_KEY] = {
        "provider" => auth.provider,
        "workspace_id" => current_workspace.id,
        "state" => auth.state,
        "verifier" => auth.verifier,
        "expires_at" => StartAuthorization::TTL.from_now.iso8601
      }

      # allow_other_host: leaving for the platform is the entire point.
      redirect_to auth.url, allow_other_host: true
    end

    private

    def failure_message(error)
      case error
      when :unknown_provider then "That platform is not supported."
      when :not_configured
        "That platform has not been set up with API credentials yet, so it cannot be connected."
      else "That connection could not be started."
      end
    end
  end
end
