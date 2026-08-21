module Settings
  class BillingController < BaseController
    def show
      @subscription = current_workspace.subscription
      @plans = Plan.active.for_interval(@subscription&.plan&.interval || "month")
                   .in_display_order.includes(:plan_entitlements)
      @usage = Billing::UsageSummary.new(workspace: current_workspace).call
    end
  end
end
