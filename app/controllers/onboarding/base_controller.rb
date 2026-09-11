module Onboarding
  class BaseController < ApplicationController
    include WorkspaceScoping

    layout "onboarding"

    helper_method :onboarding_steps, :current_step_key

    private

    # For the steps that only some account types walk. A creator who follows an
    # old link to Business setup is not doing anything wrong, so they are moved
    # to where they actually belong rather than shown a form that leads nowhere.
    def skip_step_not_in_flow
      return if OnboardingFlow.includes?(current_step_key, current_workspace.account_type)

      redirect_to OnboardingFlow.path_for(current_workspace.onboarding_step, current_workspace)
    end

    def onboarding_steps = OnboardingFlow.steps(current_workspace.account_type)

    # Each step controller declares which step it is, so the progress bar and
    # the resume logic read from one place.
    def current_step_key
      raise NotImplementedError, "#{self.class} must define current_step_key"
    end

    def record_progress(step_key)
      furthest = OnboardingFlow.furthest(current_workspace.onboarding_step, step_key, current_workspace.account_type)
      return if furthest == current_workspace.onboarding_step

      current_workspace.update!(onboarding_step: furthest)
    end
  end
end
