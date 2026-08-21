module Settings
  class CatalogController < BaseController
    TABS = %w[products services].freeze

    def show
      @tab = params[:tab].presence_in(TABS) || "products"
      @products = current_workspace.products.in_display_order
      @services = current_workspace.services.in_display_order
      @product = Product.new(currency: current_workspace.currency)
      @service = Service.new(currency: current_workspace.currency)
    end
  end
end
