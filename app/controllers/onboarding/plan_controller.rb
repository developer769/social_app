module Onboarding
  class PlanController < BaseController
    def show
      record_progress(current_step_key)
    end

    private

    def current_step_key = "plan"
  end
end
