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

    def edit
      redirect_to return_path(tab: "services", edit_service: service.id)
    end

    def availability
      status = params[:availability_status].to_s

      unless Service::AVAILABILITY_STATUSES.include?(status)
        return redirect_to return_path(tab: "services"), alert: "That is not an availability state."
      end

      service.update!(availability_status: status)
      AuditEvent.record!(action: "service.availability_changed", workspace: current_workspace,
                         actor_user: current_user, auditable: service,
                         metadata: { availability_status: status })

      redirect_to return_path(tab: "services"),
                  notice: "#{service.name} is now #{status.humanize.downcase}."
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

    # Back where you came from. This always returned to the onboarding catalog,
    # so adding or editing from Settings dropped you into the setup flow.
    def return_path(tab: "services", **extra)
      if current_workspace.onboarding_completed?
        workspace_settings_catalog_path(workspace_slug: current_workspace.slug, tab: tab, **extra)
      else
        workspace_onboarding_catalog_path(workspace_slug: current_workspace.slug, tab: tab, **extra)
      end
    end

    def error_message(record)
      record.respond_to?(:errors) ? record.errors.full_messages.to_sentence : "That could not be saved."
    end
  end
end
