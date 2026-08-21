module Settings
  class BaseController < ApplicationController
    include WorkspaceScoping

    layout "application"

    private

    def slug = { workspace_slug: current_workspace.slug }
  end
end
