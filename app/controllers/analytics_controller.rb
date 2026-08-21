class AnalyticsController < ApplicationController
  include WorkspaceScoping

  def show
    @overview = Analytics::OverviewQuery.new(workspace: current_workspace, days: period)
  end

  private

  def period = params[:days].to_i
end
