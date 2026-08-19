module Connections
  class SocialAccountsController < ApplicationController
    include WorkspaceScoping

    layout "onboarding"

    def create
      result = ConnectAccount.call(
        workspace: current_workspace, provider: params[:provider], actor: current_user
      )

      if result.success?
        redirect_to return_path, notice: "#{result.value.provider_name} connected as #{result.value.handle}."
      else
        redirect_to return_path, alert: failure_message(result.error)
      end
    end

    def destroy
      result = DisconnectAccount.call(
        workspace: current_workspace, account: account, actor: current_user
      )

      redirect_to return_path,
        notice: (result.success? ? "#{result.value.provider_name} disconnected." : nil),
        alert: (result.failure? ? "That account could not be disconnected." : nil)
    end

    private

    def account = @account ||= current_workspace.social_accounts.find(params[:id])

    def return_path
      workspace_onboarding_connections_path(workspace_slug: current_workspace.slug)
    end

    def failure_message(error)
      case error
      when :unknown_provider then "That platform is not supported."
      when SocialProvider::PermanentError then error.message
      when SocialProvider::TransientError then "#{error.message} Please try again shortly."
      else "That account could not be connected."
      end
    end
  end
end
