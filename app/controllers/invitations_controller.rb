# Accepting an invitation.
#
# Open to signed-out visitors, because the person invited very often has no
# Prachar account yet.
class InvitationsController < ApplicationController
  allow_unauthenticated_access

  layout "authentication"

  before_action :set_membership

  def show
    @user = User.new(email: @membership.invitation_email)
  end

  def accept
    if signed_in?
      accept_as(current_user)
    else
      accept_as_new_user
    end
  end

  def decline
    @membership.decline_invitation!
    AuditEvent.record!(action: "workspace_membership.declined", workspace: @membership.workspace,
                       auditable: @membership)
    redirect_to login_path, notice: "Invitation declined."
  end

  private

  def set_membership
    @membership = WorkspaceMembership.find_by_invitation_token(params[:token])

    # Identical response for an unknown, used, cancelled or expired token, so a
    # guessed token reveals nothing about whether it ever existed.
    return render :invalid, status: :not_found if @membership.nil? || !@membership.invitation_pending?
    render :expired, status: :gone if @membership.invitation_expired?
  end

  def accept_as(user)
    @membership.accept_invitation!(user: user)
    audit_acceptance
    start_new_session_for(user) unless signed_in?
    redirect_to workspace_root_path(workspace_slug: @membership.workspace.slug),
                notice: "You have joined #{@membership.workspace.name}."
  end

  def accept_as_new_user
    existing = User.find_by(email: @membership.invitation_email)
    return accept_as(existing) if existing

    @user = User.new(user_params.merge(email: @membership.invitation_email))

    if @user.save
      accept_as(@user)
    else
      render :show, status: :unprocessable_content
    end
  end

  def audit_acceptance
    AuditEvent.record!(action: "workspace_membership.accepted", workspace: @membership.workspace,
                       actor_user: @membership.user, auditable: @membership)
  end

  def user_params = params.expect(user: %i[name password])
end
