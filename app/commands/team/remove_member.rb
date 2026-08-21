module Team
  class RemoveMember < ApplicationCommand
    def initialize(workspace:, membership:, actor:)
      @workspace = workspace
      @membership = membership
      @actor = actor
    end

    def call
      return Result.failure(:not_in_workspace) unless @membership.workspace_id == @workspace.id
      # The creator holds the operations nobody else can perform yet, so
      # removing them would leave the workspace unownable (spec 2).
      return Result.failure(:cannot_remove_owner) if owner?

      ActiveRecord::Base.transaction do
        @membership.remove!
        # Access ends now, not when their session happens to expire.
        Session.where(user_id: @membership.user_id).update_all(revoked_at: Time.current) if @membership.user_id

        AuditEvent.record!(
          action: "workspace_membership.removed",
          workspace: @workspace, actor_user: @actor, auditable: @membership,
          metadata: { removed_user_id: @membership.user_id }
        )
      end

      Result.success(@membership)
    end

    private

    def owner? = @membership.user_id.present? && @membership.user_id == @workspace.owner_user_id
  end
end
