module Catalog
  class SaveService < ApplicationCommand
    def initialize(workspace:, dto:, actor:, service: nil)
      @workspace = workspace
      @dto = dto
      @actor = actor
      @service = service
    end

    def call
      service = @service || @workspace.services.new
      creating = service.new_record?

      ActiveRecord::Base.transaction do
        service.assign_attributes(@dto.to_attributes)
        service.cover_image.attach(@dto.cover_image) if @dto.cover_image.present?
        service.save!

        AuditEvent.record!(
          action: creating ? "service.created" : "service.updated",
          workspace: @workspace,
          actor_user: @actor,
          auditable: service,
          metadata: { name: service.name }
        )
      end

      Result.success(service)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
