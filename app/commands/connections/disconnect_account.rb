module Connections
  # Disconnecting destroys the stored tokens rather than merely flagging the
  # account: a token we no longer use is a liability, not a convenience.
  class DisconnectAccount < ApplicationCommand
    def initialize(workspace:, account:, actor:)
      @workspace = workspace
      @account = account
      @actor = actor
    end

    def call
      return Result.failure(:not_in_workspace) unless @account.workspace_id == @workspace.id

      ActiveRecord::Base.transaction do
        @account.social_credential&.destroy!
        @account.mark_disconnected!

        AuditEvent.record!(
          action: "social_account.disconnected",
          workspace: @workspace,
          actor_user: @actor,
          auditable: @account,
          metadata: { provider: @account.provider, handle: @account.handle }
        )
      end

      Result.success(@account)
    end
  end
end
