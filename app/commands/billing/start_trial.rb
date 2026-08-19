module Billing
  # Starts a trial on the chosen plan and finishes onboarding.
  #
  # No payment is taken and no card is collected: nothing is charged, so the
  # button says "Start trial" and means it. A payment provider is not contracted
  # yet, so provider fields stay null until one is.
  class StartTrial < ApplicationCommand
    def initialize(workspace:, plan:, actor:)
      @workspace = workspace
      @plan = plan
      @actor = actor
    end

    def call
      return Result.failure(:plan_unavailable) unless @plan&.active?

      subscription = nil

      ActiveRecord::Base.transaction do
        subscription = @workspace.subscription || @workspace.build_subscription
        subscription.assign_attributes(
          plan: @plan,
          selected_by: @actor,
          status: "trialing",
          trial_ends_at: @plan.trial_days.days.from_now,
          current_period_start: Time.current,
          current_period_end: @plan.billed_year? ? 1.year.from_now : 1.month.from_now,
          cancelled_at: nil
        )
        subscription.save!

        @workspace.update!(
          onboarding_step: "completed",
          onboarding_completed_at: @workspace.onboarding_completed_at || Time.current
        )

        AuditEvent.record!(
          action: "subscription.trial_started",
          workspace: @workspace,
          actor_user: @actor,
          auditable: subscription,
          metadata: { plan: @plan.code, interval: @plan.interval, trial_days: @plan.trial_days }
        )
      end

      Result.success(subscription)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
