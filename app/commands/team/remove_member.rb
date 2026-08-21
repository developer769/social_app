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

        # Their sessions are deliberately left alone. Access to a workspace is
        # resolved from an accepted, active membership on every single request,
        # so removal takes effect on their very next click without touching
        # anything. Revoking sessions here also signed them out of every OTHER
        # workspace they belong to -- including their own -- which is not what
        # removing somebody from one workspace should ever do.
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
