module Onboarding
  class AnalysisController < BaseController
    def show
      @analysis = current_workspace.brand_analyses.recent_first.first
      record_progress(current_step_key)
    end

    def create
      result = ::Analysis::StartBrandAnalysis.call(workspace: current_workspace, actor: current_user)

      if result.success?
        redirect_to workspace_onboarding_analysis_path(workspace_slug: current_workspace.slug)
      else
        redirect_to workspace_onboarding_analysis_path(workspace_slug: current_workspace.slug),
                    alert: "The analysis could not be started."
      end
    end

    def complete
      current_workspace.update!(
        onboarding_step: OnboardingFlow.furthest(
          current_workspace.onboarding_step, OnboardingFlow.next_key(current_step_key)
        )
      )
      redirect_to OnboardingFlow.path_for(OnboardingFlow.next_key(current_step_key), current_workspace)
    end

    private

    def current_step_key = "analysis"
  end
end
