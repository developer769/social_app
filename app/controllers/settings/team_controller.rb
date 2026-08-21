module Settings
  class TeamController < BaseController
    def index
      @members = current_workspace.workspace_memberships.accepted.active.includes(:user).order(:accepted_at)
      @pending = current_workspace.workspace_memberships.pending.includes(:invited_by).order(invited_at: :desc)
      @seat_limit = current_workspace.subscription&.limit_for("team_members")
      @seats_used = @members.size + @pending.size
    end

    def create
      if seats_exhausted?
        return redirect_to workspace_settings_team_index_path(**slug),
                           alert: "Your plan includes #{@seat_limit} #{'seat'.pluralize(@seat_limit)}. Upgrade to invite more people."
      end

      result = ::Team::InviteMember.call(
        workspace: current_workspace, email: params[:email], actor: current_user
      )

      if result.success?
        redirect_to workspace_settings_team_index_path(**slug),
                    notice: "Invitation sent to #{result.value.invitation_email}."
      else
        redirect_to workspace_settings_team_index_path(**slug), alert: invite_error(result.error)
      end
    end

    def resend
      membership = current_workspace.workspace_memberships.pending.find(params[:id])
      membership.issue_invitation!(invited_by: current_user)
      TeamMailer.invitation(membership, membership.raw_invitation_token).deliver_later

      redirect_to workspace_settings_team_index_path(**slug),
                  notice: "Invitation resent to #{membership.invitation_email}."
    end

    def destroy
      membership = current_workspace.workspace_memberships.find(params[:id])

      if membership.invitation_pending?
        membership.cancel_invitation!
        AuditEvent.record!(action: "workspace_membership.invitation_cancelled",
                           workspace: current_workspace, actor_user: current_user, auditable: membership)
        return redirect_to workspace_settings_team_index_path(**slug), notice: "Invitation cancelled."
      end

      result = ::Team::RemoveMember.call(
        workspace: current_workspace, membership: membership, actor: current_user
      )

      redirect_to workspace_settings_team_index_path(**slug),
                  notice: (result.success? ? "Removed from this workspace." : nil),
                  alert: (result.failure? ? removal_error(result.error) : nil)
    end

    private

    def seats_exhausted?
      index_counts
      return false if @seat_limit.nil?

      @seats_used >= @seat_limit
    end

    def index_counts
      @seat_limit ||= current_workspace.subscription&.limit_for("team_members")
      @seats_used ||= current_workspace.workspace_memberships.where(invitation_status: %w[accepted pending])
                                       .where.not(membership_status: "removed").count
    end

    def invite_error(error)
      case error
      when :email_required then "Enter an email address."
      when :invalid_email then "That does not look like an email address."
      when :already_a_member then "That person is already in this workspace."
      when :already_invited then "They already have an invitation waiting. Resend it instead."
      else "That invitation could not be sent."
      end
    end

    def removal_error(error)
      return "The workspace owner cannot be removed." if error == :cannot_remove_owner

      "That person could not be removed."
    end
  end
end
