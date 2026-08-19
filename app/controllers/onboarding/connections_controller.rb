module Onboarding
  class ConnectionsController < BaseController
    def show
      @accounts_by_provider = current_workspace.social_accounts.index_by(&:provider)
      @providers = SocialProvider::Catalog.all
      record_progress(current_step_key)
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

    def current_step_key = "connections"
  end
end
