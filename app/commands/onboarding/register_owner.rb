module Onboarding
  # Creates the three records that must exist together for a new business:
  # the person, their workspace, and the membership that grants them access.
  # Wrapped in a transaction because a workspace with no member is unreachable
  # and a user with no workspace has nowhere to land.
  class RegisterOwner < ApplicationCommand
    Registration = Struct.new(:user, :workspace, :membership, keyword_init: true)

    def initialize(dto:, ip_address: nil)
      @dto = dto
      @ip_address = ip_address
    end

    def call
      user = User.new(name: @dto.name, email: @dto.email, password: @dto.password)

      ActiveRecord::Base.transaction do
        user.save!

        workspace = Workspace.create!(
          name: @dto.business_name.presence || "#{@dto.name.split.first}'s business",
          owner_user: user
        )

        membership = WorkspaceMembership.create!(
          workspace: workspace,
          user: user,
          invitation_status: "accepted",
          membership_status: "active",
          accepted_at: Time.current
        )

        AuditEvent.record!(
          action: "workspace.created",
          workspace: workspace,
          actor_user: user,
          auditable: workspace,
          ip_address: @ip_address
        )

        Result.success(Registration.new(user: user, workspace: workspace, membership: membership))
      end
    rescue ActiveRecord::RecordInvalid => e
      # Returns the invalid record so the form can re-render its errors.
      Result.failure(e.record.is_a?(User) ? e.record : user)
    end
  end
end
