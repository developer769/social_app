class AnalyticsController < ApplicationController
  include WorkspaceScoping

  def show
    @overview = Analytics::OverviewQuery.new(
      workspace: current_workspace,
      from: params[:from], to: params[:to], days: params[:days]
    )
  end
end
