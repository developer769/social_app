module Onboarding
  # /onboarding sends the owner to wherever they stopped, so progress survives
  # closing the tab (spec 22).
  class ResumeController < BaseController
    def show
      redirect_to OnboardingFlow.path_for(current_workspace.onboarding_step, current_workspace)
    end

    private

    def current_step_key = OnboardingFlow.resolve(current_workspace.onboarding_step, current_workspace.account_type)
  end
end
