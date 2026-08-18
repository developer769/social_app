require "rails_helper"

RSpec.describe "Catalog" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "adding a product" do
    it "saves it and shows it in the catalog" do
      post workspace_products_path(**slug), params: {
        product: { name: "Chocolate Truffle Cake", category: "Cakes", price: "1549", featured: "1" }
      }

      expect(response).to redirect_to(workspace_onboarding_catalog_path(**slug, tab: "products"))
      product = workspace.products.sole
      expect(product.name).to eq("Chocolate Truffle Cake")
      expect(product.price_minor).to eq(154_900)
      expect(product).to be_featured
    end

    it "refuses a product with no name and says so" do
      post workspace_products_path(**slug), params: { product: { name: "", category: "Cakes" } }

      expect(workspace.products).to be_empty
      expect(flash[:alert]).to include("Name can't be blank")
    end

    it "orders products by when they were added" do
      post workspace_products_path(**slug), params: { product: { name: "First" } }
      post workspace_products_path(**slug), params: { product: { name: "Second" } }

      expect(workspace.products.in_display_order.pluck(:name)).to eq(%w[First Second])
    end
  end

  describe "adding a service" do
    it "saves a day range and renders it the way the designs word it" do
      post workspace_services_path(**slug), params: {
        service: { name: "Custom Birthday Cake", starting_price: "1999",
                   duration_min_days: "2", duration_max_days: "3" }
      }

      service = workspace.services.sole
      expect(service.duration_label).to eq("2\u20133 days")
      expect(service.starting_price_minor).to eq(199_900)
    end

    it "renders a single day without a range" do
      post workspace_services_path(**slug), params: {
        service: { name: "Event Catering", duration_min_days: "1" }
      }

      expect(workspace.services.sole.duration_label).to eq("1 day")
    end
  end

  describe "deleting" do
    it "removes the item and records it in the audit trail" do
      product = create(:product, workspace: workspace, name: "Brownie Box")

      expect { delete workspace_product_path(**slug, id: product) }
        .to change { workspace.products.count }.by(-1)
        .and change { AuditEvent.where(action: "product.deleted").count }.by(1)
    end
  end

  describe "tenant isolation" do
    let(:other) { create(:workspace) }

    before { create(:workspace_membership, workspace: other, user: create(:user)) }

    it "cannot add a product to another workspace" do
      post workspace_products_path(workspace_slug: other.slug), params: { product: { name: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(other.products).to be_empty
    end

    it "cannot delete another workspace's product even from inside its own" do
      theirs = create(:product, workspace: other, name: "Their Cake")

      delete workspace_product_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
      expect(other.products.reload).to include(theirs)
    end
  end

  describe "progress recording" do
    # Regression: the catalog page used to build its blank form objects through
    # current_workspace.products.new, which appended them to the association.
    # Recording progress then ran autosave validation over those blanks and the
    # whole page 422'd, but only once a flash redirect brought you back to it.
    it "renders after a failed save, when a flash is being shown" do
      post workspace_products_path(**slug), params: { product: { name: "" } }
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Name can&#39;t be blank")
    end

    it "records the step without being blocked by unsaved form objects" do
      workspace.update!(onboarding_step: "business_setup")

      get workspace_onboarding_catalog_path(**slug)

      expect(response).to have_http_status(:ok)
      expect(workspace.reload.onboarding_step).to eq("catalog")
    end
  end

  describe "continuing" do
    it "advances onboarding to the connections step" do
      post workspace_onboarding_catalog_complete_path(**slug)

      expect(response).to redirect_to(workspace_onboarding_connections_path(**slug))
      expect(workspace.reload.onboarding_step).to eq("connections")
    end
  end
end
