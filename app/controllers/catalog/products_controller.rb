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

    def edit
      redirect_to return_path(tab: "products", edit_product: product.id)
    end

    # One tap, no form. Stock changes several times a day and is the only field
    # that does; everything else is a trip through edit.
    def stock
      status = params[:stock_status].to_s

      unless Product::STOCK_STATUSES.include?(status)
        return redirect_to return_path(tab: "products"), alert: "That is not a stock state."
      end

      product.update!(stock_status: status)
      AuditEvent.record!(action: "product.stock_changed", workspace: current_workspace,
                         actor_user: current_user, auditable: product,
                         metadata: { stock_status: status })

      redirect_to return_path(tab: "products"), notice: stock_notice(product)
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

    def stock_notice(product)
      case product.stock_status
      when "out_of_stock"
        "#{product.name} is marked sold out. It will not be offered for new posts."
      when "low_stock" then "#{product.name} is marked low on stock."
      else "#{product.name} is back in stock."
      end
    end

    # Scoped to the workspace, so an id from another tenant is simply not found.
    def product = @product ||= current_workspace.products.find(params[:id])

    def build_dto
      ProductDto.new(**permitted.to_h.symbolize_keys, currency: current_workspace.currency)
    end

    def permitted
      params.expect(product: %i[name category price description url availability_status
                                stock_status featured price_is_starting_from image])
    end

    # Back where you came from. This always returned to the onboarding catalog,
    # so adding or editing an item from Settings dropped you into the setup
    # flow. Onboarding's copy is only reachable during onboarding.
    def return_path(tab:, **extra)
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
