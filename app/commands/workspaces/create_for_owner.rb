module Workspaces
  # Creates an additional workspace for someone who already has an account.
  #
  # Exists because a user can legitimately end up with no workspace -- their
  # only membership was removed -- and without this they would be signed in
  # with nowhere to go.
  class CreateForOwner < ApplicationCommand
    def initialize(user:, name:, ip_address: nil)
      @user = user
      @name = name.to_s.strip
      @ip_address = ip_address
    end

    def call
      workspace = Workspace.new(name: @name, owner_user: @user)

      ActiveRecord::Base.transaction do
        workspace.save!

        WorkspaceMembership.create!(
          workspace: workspace,
          user: @user,
          invitation_status: "accepted",
          membership_status: "active",
          accepted_at: Time.current
        )

        AuditEvent.record!(
          action: "workspace.created",
          workspace: workspace,
          actor_user: @user,
          auditable: workspace,
          ip_address: @ip_address
        )
      end

      Result.success(workspace)
    rescue ActiveRecord::RecordInvalid
      Result.failure(workspace)
    end
  end
end
