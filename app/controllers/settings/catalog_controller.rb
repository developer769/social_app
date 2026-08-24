module Settings
  class CatalogController < BaseController
    TABS = %w[products services].freeze

    def show
      # The tab follows what is being edited, or Edit on a service would open
      # the products tab with the service form hidden behind it.
      @tab = params[:tab].presence_in(TABS) ||
             (params[:edit_service].present? ? "services" : "products")
      @products = current_workspace.products.in_display_order
      @services = current_workspace.services.in_display_order
      # A form already filled in when arriving from Edit, a blank one otherwise.
      # Looked up through the workspace, so another tenant's id is simply absent.
      @product = current_workspace.products.find_by(id: params[:edit_product]) ||
                 Product.new(currency: current_workspace.currency)
      @service = current_workspace.services.find_by(id: params[:edit_service]) ||
                 Service.new(currency: current_workspace.currency)
    end
  end
end
