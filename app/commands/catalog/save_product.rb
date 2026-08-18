module Catalog
  # Creates or updates one product. Image attachment and audit belong here
  # rather than in a model callback, so the write is explicit and testable.
  class SaveProduct < ApplicationCommand
    def initialize(workspace:, dto:, actor:, product: nil)
      @workspace = workspace
      @dto = dto
      @actor = actor
      @product = product
    end

    def call
      product = @product || @workspace.products.new
      creating = product.new_record?

      ActiveRecord::Base.transaction do
        product.assign_attributes(@dto.to_attributes)
        # Replacing the image swaps the file; nothing edits it (spec 2).
        product.image.attach(@dto.image) if @dto.image.present?
        product.save!

        AuditEvent.record!(
          action: creating ? "product.created" : "product.updated",
          workspace: @workspace,
          actor_user: @actor,
          auditable: product,
          metadata: { name: product.name }
        )
      end

      Result.success(product)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
