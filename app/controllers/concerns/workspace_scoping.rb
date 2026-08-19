module WorkspaceScoping
  extend ActiveSupport::Concern

  included do
    before_action :require_workspace
    helper_method :current_workspace, :current_membership, :available_workspaces

    # A signed-in person who follows a stale link, mistypes a slug, or was
    # removed from a workspace is not an attacker, and a bare "record not
    # found" tells them nothing and offers no way out. They get a page that
    # explains and points at the workspaces they can actually open.
    #
    # The wording is identical whether the workspace exists or not, so this
    # still reveals nothing (spec 7).
    rescue_from ActiveRecord::RecordNotFound, with: :workspace_unavailable
  end

  private

  def current_workspace
    Current.workspace
  end

  def current_membership
    Current.membership
  end

  def available_workspaces
    current_user.workspaces.order(:name)
  end

  # The workspace slug in the URL is a lookup key, never a grant. Access is
  # resolved from the authenticated user's own accepted, active membership, so
  # a slug belonging to someone else's workspace simply does not resolve
  # (spec 7). Missing rather than forbidden: a 404 does not confirm existence.
  def workspace_unavailable
    @attempted_slug = params[:workspace_slug]
    render "shared/workspace_unavailable", status: :not_found, layout: "authentication"
  end

  def require_workspace
    membership = current_user
      .accepted_memberships
      .joins(:workspace)
      .find_by(workspaces: { slug: params[:workspace_slug] })

    raise ActiveRecord::RecordNotFound if membership.nil?

    Current.membership = membership
    Current.workspace = membership.workspace
  end
end
