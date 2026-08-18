module Onboarding
  class BaseController < ApplicationController
    include WorkspaceScoping

    layout "onboarding"

    helper_method :onboarding_steps, :current_step_key

    private

    def onboarding_steps = OnboardingFlow.steps

    # Each step controller declares which step it is, so the progress bar and
    # the resume logic read from one place.
    def current_step_key
      raise NotImplementedError, "#{self.class} must define current_step_key"
    end

    def record_progress(step_key)
      furthest = OnboardingFlow.furthest(current_workspace.onboarding_step, step_key)
      return if furthest == current_workspace.onboarding_step

      current_workspace.update!(onboarding_step: furthest)
    end
  end
end
