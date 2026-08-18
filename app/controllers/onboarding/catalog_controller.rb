module Onboarding
  class CatalogController < BaseController
    def show
      record_progress(current_step_key)
    end

    private

    def current_step_key = "catalog"
  end
end
