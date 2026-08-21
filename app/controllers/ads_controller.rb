class AdsController < ApplicationController
  include WorkspaceScoping

  def show
    @readiness = Ads::ReadinessQuery.new(workspace: current_workspace)
  end
end
