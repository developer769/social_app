class AdsController < ApplicationController
  include WorkspaceScoping

  def show
    @readiness = Ads::ReadinessQuery.new(workspace: current_workspace)
    @performance = Ads::PerformanceQuery.new(workspace: current_workspace, days: params[:days].to_i)
  end
end
