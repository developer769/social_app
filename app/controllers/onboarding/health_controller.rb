module Onboarding
  class HealthController < BaseController
    def show
      record_progress(current_step_key)
    end

    private

    def current_step_key = "health"
  end
end
