module Catalog
  class ServicesController < ApplicationController
    include WorkspaceScoping

    layout "onboarding"

    def create
      result = SaveService.call(workspace: current_workspace, dto: build_dto, actor: current_user)

      if result.success?
        redirect_to return_path, notice: "#{result.value.name} was added."
      else
        redirect_to return_path, alert: error_message(result.error)
      end
    end

    def update
      result = SaveService.call(
        workspace: current_workspace, dto: build_dto, actor: current_user, service: service
      )

      if result.success?
        redirect_to return_path, notice: "#{result.value.name} was updated."
      else
        redirect_to return_path, alert: error_message(result.error)
      end
    end

    def destroy
      result = RemoveItem.call(workspace: current_workspace, item: service, actor: current_user)

      redirect_to return_path,
        notice: (result.success? ? "#{result.value} was deleted." : nil),
        alert: (result.failure? ? "That item could not be deleted." : nil)
    end

    private

    def service = @service ||= current_workspace.services.find(params[:id])

    def build_dto
      ServiceDto.new(**permitted.to_h.symbolize_keys, currency: current_workspace.currency)
    end

    def permitted
      params.expect(service: %i[name category starting_price duration_min_days duration_max_days
                                description booking_url availability_status featured cover_image])
    end

    def return_path
      workspace_onboarding_catalog_path(workspace_slug: current_workspace.slug, tab: "services")
    end

    def error_message(record)
      record.respond_to?(:errors) ? record.errors.full_messages.to_sentence : "That could not be saved."
    end
  end
end
