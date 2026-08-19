module Onboarding
  class PlanController < BaseController
    INTERVALS = %w[month year].freeze

    def show
      @interval = INTERVALS.include?(params[:interval]) ? params[:interval] : "month"
      @plans = Plan.active.for_interval(@interval).in_display_order.includes(:plan_entitlements)
      @monthly_by_code = Plan.active.for_interval("month").index_by(&:code)
      @subscription = current_workspace.subscription
      record_progress(current_step_key)
    end

    def create
      plan = Plan.active.find_by(id: params[:plan_id])
      result = ::Billing::StartTrial.call(workspace: current_workspace, plan: plan, actor: current_user)

      if result.success?
        redirect_to workspace_root_path(workspace_slug: current_workspace.slug),
                    notice: "Your #{result.value.plan.name} trial has started. You are all set up."
      else
        redirect_to workspace_onboarding_plan_path(workspace_slug: current_workspace.slug),
                    alert: "That plan is not available. Please choose another."
      end
    end

    private

    def current_step_key = "plan"
  end
end
