class DashboardController < ApplicationController
  include WorkspaceScoping

  def show
    @overview = Dashboard::OverviewQuery.new(workspace: current_workspace, user: current_user)
  end
end
