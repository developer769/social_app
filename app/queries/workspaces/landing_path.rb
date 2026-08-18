module Workspaces
  # Where a freshly authenticated person should land: straight into their
  # workspace when there is exactly one, otherwise the picker.
  class LandingPath
    include Rails.application.routes.url_helpers

    def initialize(user:)
      @user = user
    end

    def call
      workspaces = @user.workspaces.order(:name)

      return workspaces_path if workspaces.size != 1

      workspace_root_path(workspace_slug: workspaces.first.slug)
    end
  end
end
