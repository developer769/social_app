module Settings
  class BrandKitController < BaseController
    def show
      @brand_kit = brand_kit
    end

    def update
      @brand_kit = brand_kit

      if @brand_kit.update(brand_kit_params)
        AuditEvent.record!(action: "brand_kit.updated", workspace: current_workspace,
                           actor_user: current_user, auditable: @brand_kit)
        redirect_to workspace_settings_brand_kit_path(**slug), notice: "Saved."
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def brand_kit
      current_workspace.brand_kit || current_workspace.create_brand_kit!
    end

    def brand_kit_params
      params.expect(brand_kit: %i[primary_color secondary_color accent_color
                                  heading_font body_font usage_notes
                                  logo logo_on_dark icon])
    end
  end
end
