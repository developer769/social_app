class WorkspacesController < ApplicationController
  # No sidebar here: there is no current workspace to render one for.
  layout "authentication"

  # Shown when someone belongs to several businesses, or to none yet.
  def index
    @workspaces = current_user.workspaces.order(:name)

    redirect_to workspace_root_path(workspace_slug: @workspaces.first.slug) if @workspaces.one?
  end
end
