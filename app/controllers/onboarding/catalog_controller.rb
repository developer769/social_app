module Onboarding
  class CatalogController < BaseController
    TABS = %w[products services].freeze

    before_action :set_collections

    def show
      # Built detached, not through current_workspace.products.new: building
      # through the association appends the blank record to it, and the next
      # workspace.update! then fails autosave validation with "Products is
      # invalid". These objects only supply form defaults.
      @product = Product.new(currency: current_workspace.currency)
      @service = Service.new(currency: current_workspace.currency)
      record_progress(current_step_key)
    end

    # Advancing is a separate action from adding an item, so "Continue" never
    # silently discards a half-filled form.
    def complete
      current_workspace.update!(
        onboarding_step: OnboardingFlow.furthest(
          current_workspace.onboarding_step, OnboardingFlow.next_key(current_step_key)
        )
      )
      redirect_to OnboardingFlow.path_for(OnboardingFlow.next_key(current_step_key), current_workspace)
    end

    private

    def current_step_key = "catalog"

    def set_collections
      @products = current_workspace.products.in_display_order
      @services = current_workspace.services.in_display_order
      @tab = TABS.include?(params[:tab]) ? params[:tab] : "products"
    end
  end
end
