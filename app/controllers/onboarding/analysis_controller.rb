module Onboarding
  class AnalysisController < BaseController
    def show
      record_progress(current_step_key)
    end

    private

    def current_step_key = "analysis"
  end
end
