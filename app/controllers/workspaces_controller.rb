class WorkspacesController < ApplicationController
  # No sidebar here: there is no current workspace to render one for.
  layout "authentication"

  # Shown when someone belongs to several businesses, or to none at all.
  def index
    @workspaces = current_user.workspaces.order(:name)

    redirect_to workspace_root_path(workspace_slug: @workspaces.first.slug) if @workspaces.one?
  end

  def new
    @workspace = Workspace.new
  end

  def create
    result = Workspaces::CreateForOwner.call(
      user: current_user, name: params.dig(:workspace, :name), ip_address: request.remote_ip
    )

    if result.success?
      redirect_to workspace_root_path(workspace_slug: result.value.slug)
    else
      @workspace = result.error
      render :new, status: :unprocessable_content
    end
  end
end
