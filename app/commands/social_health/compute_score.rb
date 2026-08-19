module SocialHealth
  # Computes and stores a score. Kept as a command rather than a model callback
  # so the inputs are recorded alongside the result and the number can always be
  # explained after the fact (spec 22).
  class ComputeScore < ApplicationCommand
    def initialize(workspace:, actor: nil)
      @workspace = workspace
      @actor = actor
    end

    def call
      outcome = Calculator.call(workspace: @workspace)

      record = @workspace.social_health_scores.create!(
        score: outcome.score,
        rating: outcome.rating,
        coverage_percentage: outcome.coverage_percentage,
        components: outcome.components.map(&:to_h),
        computed_at: Time.current
      )

      AuditEvent.record!(
        action: "social_health.computed",
        workspace: @workspace,
        actor_user: @actor,
        auditable: record,
        metadata: { score: outcome.score, coverage: outcome.coverage_percentage }
      )

      Result.success(record)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
