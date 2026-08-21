module Team
  # Invites someone to help run a workspace.
  #
  # No role is chosen, because roles are deliberately undefined (spec 2). An
  # accepted member gets the same access as everyone else, and this command
  # cannot be extended to grant less without that decision being made first.
  class InviteMember < ApplicationCommand
    def initialize(workspace:, email:, actor:)
      @workspace = workspace
      @email = email.to_s.strip.downcase.presence
      @actor = actor
    end

    def call
      return Result.failure(:email_required) if @email.blank?
      return Result.failure(:invalid_email) unless @email.match?(URI::MailTo::EMAIL_REGEXP)
      return Result.failure(:already_a_member) if already_a_member?

      membership = existing_reusable_invitation || @workspace.workspace_memberships.new(invitation_email: @email)

      ActiveRecord::Base.transaction do
        membership.save!
        membership.issue_invitation!(invited_by: @actor)

        AuditEvent.record!(
          action: "workspace_membership.invited",
          workspace: @workspace, actor_user: @actor, auditable: membership,
          # The address is the point of the record here, unlike a failed login.
          metadata: { invitation_email: @email }
        )
      end

      # The raw token exists only in memory, so the mail has to be sent from
      # here rather than from a job that would have to be handed the token.
      TeamMailer.invitation(membership, membership.raw_invitation_token).deliver_later

      Result.success(membership)
    rescue ActiveRecord::RecordNotUnique
      Result.failure(:already_invited)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def already_a_member?
      @workspace.workspace_memberships.accepted.active
                .joins(:user).exists?(users: { email: @email })
    end

    # A declined or cancelled invitation can be reissued to the same address;
    # only a live pending one blocks, and that is handled by resending instead.
    def existing_reusable_invitation
      @workspace.workspace_memberships
                .where(invitation_email: @email)
                .where.not(invitation_status: "accepted")
                .order(created_at: :desc).first
    end
  end
end
