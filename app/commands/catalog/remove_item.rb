module Catalog
  # Deleting a catalog item is destructive and auditable, so it goes through a
  # command even though the model call is short.
  class RemoveItem < ApplicationCommand
    def initialize(workspace:, item:, actor:)
      @workspace = workspace
      @item = item
      @actor = actor
    end

    def call
      return Result.failure(:not_in_workspace) unless @item.workspace_id == @workspace.id

      name = @item.name

      ActiveRecord::Base.transaction do
        @item.destroy!

        AuditEvent.record!(
          action: "#{@item.model_name.singular}.deleted",
          workspace: @workspace,
          actor_user: @actor,
          metadata: { name: name }
        )
      end

      Result.success(name)
    rescue ActiveRecord::RecordNotDestroyed
      Result.failure(@item)
    end
  end
end
