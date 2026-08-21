class AdsController < ApplicationController
  include WorkspaceScoping

  def show
    @readiness = Ads::ReadinessQuery.new(workspace: current_workspace)
    @performance = Ads::PerformanceQuery.new(workspace: current_workspace, days: params[:days].to_i)
  end

  # Recording where a platform should watch for purchases.
  #
  # Prachar cannot measure revenue on its own, but a business that HAS put a
  # pixel on a website can say so, and from then on purchase value is requested
  # with every figures pull.
  def tracking
    submitted = params.fetch(:tracking, {}).to_unsafe_h
    updated = 0

    # Looked up through the workspace, so an account id from somebody else's
    # browser simply is not found.
    current_workspace.social_accounts.connected.where(id: submitted.keys).find_each do |account|
      id = submitted[account.id.to_s]
      next if id.to_s.strip == account.conversion_tracking_id.to_s

      account.record_conversion_tracking!(id)
      updated += 1
    end

    if updated.positive?
      AuditEvent.record!(action: "ad_tracking.updated", workspace: current_workspace,
                         actor_user: current_user, metadata: { accounts: updated })
    end

    redirect_to workspace_ads_path(workspace_slug: current_workspace.slug),
                notice: tracking_notice(updated)
  end

  private

  def tracking_notice(updated)
    return "Nothing changed." if updated.zero?

    "Saved. Purchase figures will be requested from now on, and usually arrive a day behind."
  end
end
