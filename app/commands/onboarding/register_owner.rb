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
          name: @dto.business_name.presence || default_workspace_name,
          owner_user: user,
          account_type: @dto.account_type
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

      # Proving the address matters more than it looks: it is where a password
      # reset goes, so an account created with a typo has no way back in. This
      # does not block anything -- it prompts, and the security page says
      # whether it was ever done.
      verification = EmailVerification.issue!(user: user, email: user.email, purpose: "signup",
                                              ip: @ip_address)
      if verification
        UserMailer.confirm_email(user, user.email, verification.raw_token,
                                 purpose: "signup").deliver_later
      end

      Result.success(Registration.new(user: user, workspace: workspace, membership: membership))
      end
    rescue ActiveRecord::RecordInvalid => e
      # Returns the invalid record so the form can re-render its errors.
      Result.failure(e.record.is_a?(User) ? e.record : user)
    end

    private

    # A creator who leaves the name blank should not end up with a workspace
    # called "Anaya's business".
    def default_workspace_name
      first = @dto.name.to_s.split.first.presence || "My"
      @dto.influencer? ? "#{first}'s channel" : "#{first}'s business"
    end
  end
end
