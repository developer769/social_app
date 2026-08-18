module Catalog
  class ProductsController < ApplicationController
    include WorkspaceScoping

    layout "onboarding"

    def create
      result = SaveProduct.call(workspace: current_workspace, dto: build_dto, actor: current_user)

      if result.success?
        redirect_to return_path(tab: "products"), notice: "#{result.value.name} was added."
      else
        redirect_to return_path(tab: "products"), alert: error_message(result.error)
      end
    end

    def update
      result = SaveProduct.call(
        workspace: current_workspace, dto: build_dto, actor: current_user, product: product
      )

      if result.success?
        redirect_to return_path(tab: "products"), notice: "#{result.value.name} was updated."
      else
        redirect_to return_path(tab: "products"), alert: error_message(result.error)
      end
    end

    def destroy
      result = RemoveItem.call(workspace: current_workspace, item: product, actor: current_user)

      redirect_to return_path(tab: "products"),
        notice: (result.success? ? "#{result.value} was deleted." : nil),
        alert: (result.failure? ? "That item could not be deleted." : nil)
    end

    private

    # Scoped to the workspace, so an id from another tenant is simply not found.
    def product = @product ||= current_workspace.products.find(params[:id])

    def build_dto
      ProductDto.new(**permitted.to_h.symbolize_keys, currency: current_workspace.currency)
    end

    def permitted
      params.expect(product: %i[name category price description url availability_status
                                stock_status featured price_is_starting_from image])
    end

    def return_path(tab:)
      workspace_onboarding_catalog_path(workspace_slug: current_workspace.slug, tab: tab)
    end

    def error_message(record)
      record.respond_to?(:errors) ? record.errors.full_messages.to_sentence : "That could not be saved."
    end
  end
end
