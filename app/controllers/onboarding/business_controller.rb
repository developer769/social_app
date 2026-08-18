module Onboarding
  class BusinessController < BaseController
    def show
      @profile = current_workspace.brand_profile || current_workspace.build_brand_profile
      @selected_goals = current_workspace.brand_goals.pluck(:goal)
      @selected_tones = current_workspace.brand_tones.pluck(:tone)
      record_progress(current_step_key)
    end

    def update
      result = SaveBusinessSetup.call(
        workspace: current_workspace,
        dto: build_dto,
        actor: current_user
      )

      if result.success?
        redirect_to OnboardingFlow.path_for(OnboardingFlow.next_key(current_step_key), current_workspace)
      else
        @profile = result.error.is_a?(BrandProfile) ? result.error : current_workspace.brand_profile
        @selected_goals = submitted_goals
        @selected_tones = submitted_tones
        flash.now[:alert] = "Please correct the highlighted fields."
        render :show, status: :unprocessable_content
      end
    end

    private

    def current_step_key = "business_setup"

    def build_dto
      BusinessSetupDto.new(
        **permitted.to_h.symbolize_keys,
        goals: submitted_goals,
        tones: submitted_tones
      )
    end

    def permitted
      params.fetch(:business_setup, {}).permit(
        :business_name, :category, :business_type, :contact_email,
        :phone, :website_url, :city, :timezone, :about, :logo
      )
    end

    def submitted_goals = Array(params[:goals])
    def submitted_tones = Array(params[:tones])
  end
end
