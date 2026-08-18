module Onboarding
  class ConnectionsController < BaseController
    def show
      record_progress(current_step_key)
    end

    private

    def current_step_key = "connections"
  end
end
