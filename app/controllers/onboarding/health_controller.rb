module Onboarding
  class HealthController < BaseController
    def show
      @score = current_workspace.social_health_scores.recent_first.first
      record_progress(current_step_key)
    end

    def create
      result = ::SocialHealth::ComputeScore.call(workspace: current_workspace, actor: current_user)

      redirect_to workspace_onboarding_health_path(workspace_slug: current_workspace.slug),
                  alert: (result.failure? ? "The score could not be calculated." : nil)
    end

    def complete
      current_workspace.update!(
        onboarding_step: OnboardingFlow.furthest(
          current_workspace.onboarding_step, OnboardingFlow.next_key(current_step_key, current_workspace.account_type), current_workspace.account_type
        )
      )
      redirect_to OnboardingFlow.path_for(OnboardingFlow.next_key(current_step_key, current_workspace.account_type), current_workspace)
    end

    private

    def current_step_key = "health"
  end
end
