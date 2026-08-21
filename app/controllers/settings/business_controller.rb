module Settings
  class BusinessController < BaseController
    def show
      @profile = current_workspace.brand_profile || current_workspace.build_brand_profile
      @selected_goals = current_workspace.brand_goals.pluck(:goal)
      @selected_tones = current_workspace.brand_tones.pluck(:tone)
    end

    def update
      result = Onboarding::SaveBusinessSetup.call(
        workspace: current_workspace,
        dto: build_dto,
        actor: current_user,
        # Editing settings must never rewind or advance onboarding.
        advance: false
      )

      if result.success?
        redirect_to workspace_settings_business_path(**slug), notice: "Saved."
      else
        @profile = result.error.is_a?(BrandProfile) ? result.error : current_workspace.brand_profile
        @selected_goals = Array(params[:goals])
        @selected_tones = Array(params[:tones])
        render :show, status: :unprocessable_content
      end
    end

    private

    def build_dto
      Onboarding::BusinessSetupDto.new(
        **params.fetch(:business_setup, {}).permit(
          :business_name, :category, :business_type, :contact_email,
          :phone, :website_url, :city, :timezone, :about, :logo
        ).to_h.symbolize_keys,
        goals: Array(params[:goals]),
        tones: Array(params[:tones])
      )
    end
  end
end
