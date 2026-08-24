require "rails_helper"

RSpec.describe "Editing the catalog" do
  let(:owner) { create(:user) }
  let(:workspace) do
    create(:workspace, owner_user: owner, onboarding_step: "completed",
                       onboarding_completed_at: 1.week.ago)
  end
  let!(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  # Until now the update action existed but nothing in the interface reached
  # it: the only choices were add and delete.
  describe "editing an item" do
    it "opens the catalog with the form already filled in" do
      get edit_workspace_product_path(**slug, id: product)

      follow_redirect!
      expect(body_text).to include("Edit Chocolate Truffle Cake")
      expect(response.body).to include('value="Chocolate Truffle Cake"')
    end

    it "saves a change" do
      patch workspace_product_path(**slug, id: product),
            params: { product: { name: "Chocolate Truffle Cake", price: "1799" } }

      expect(product.reload.price_minor).to eq(179_900)
    end

    it "opens the services tab when editing a service" do
      service = create(:service, workspace: workspace, name: "Wedding Dessert Table")

      get edit_workspace_service_path(**slug, id: service)
      follow_redirect!

      expect(body_text).to include("Edit Wedding Dessert Table")
    end

    # This always returned to the onboarding catalog, so editing from Settings
    # dropped somebody into the setup flow they had already finished.
    it "returns to Settings for a workspace that has finished setting up" do
      patch workspace_product_path(**slug, id: product), params: { product: { name: "Renamed" } }

      expect(response).to redirect_to(workspace_settings_catalog_path(**slug, tab: "products"))
    end

    it "returns to onboarding for a workspace still setting up" do
      workspace.update_columns(onboarding_completed_at: nil, onboarding_step: "catalog")

      patch workspace_product_path(**slug, id: product), params: { product: { name: "Renamed" } }

      expect(response).to redirect_to(
        workspace_onboarding_catalog_path(**slug, tab: "products")
      )
    end
  end

  # Stock changes several times a day. It must never mean opening a form.
  describe "marking something sold out" do
    it "changes it in one request" do
      patch stock_workspace_product_path(**slug, id: product), params: { stock_status: "out_of_stock" }

      expect(product.reload).to be_stock_out_of_stock
      expect(flash[:notice]).to include("marked sold out")
    end

    it "says it will be kept out of new posts" do
      patch stock_workspace_product_path(**slug, id: product), params: { stock_status: "out_of_stock" }

      expect(flash[:notice]).to include("will not be offered for new posts")
    end

    it "puts it back" do
      product.update!(stock_status: "out_of_stock")

      patch stock_workspace_product_path(**slug, id: product), params: { stock_status: "in_stock" }

      expect(product.reload).to be_stock_in_stock
      expect(flash[:notice]).to include("back in stock")
    end

    it "refuses a state that is not one of ours" do
      patch stock_workspace_product_path(**slug, id: product), params: { stock_status: "on_fire" }

      expect(product.reload).to be_stock_in_stock
      expect(flash[:alert]).to include("not a stock state")
    end

    it "records the change, so a disappearing product can be explained later" do
      expect {
        patch stock_workspace_product_path(**slug, id: product), params: { stock_status: "low_stock" }
      }.to change { AuditEvent.where(action: "product.stock_changed").count }.by(1)
    end

    it "does the same for a service" do
      service = create(:service, workspace: workspace)

      patch availability_workspace_service_path(**slug, id: service),
            params: { availability_status: "unavailable" }

      expect(service.reload).to be_availability_unavailable
    end

    # Spec 7.
    it "cannot change stock on another workspace's product" do
      theirs = create(:product, workspace: create(:workspace))

      patch stock_workspace_product_path(**slug, id: theirs), params: { stock_status: "out_of_stock" }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).to be_stock_in_stock
    end
  end

  # The whole reason the toggle is worth having. Without this it is faster
  # bookkeeping and nothing more.
  describe "what being sold out actually does" do
    it "keeps it out of the choices for a new post" do
      draft = create(:post, workspace: workspace, template: create(:template))
      product.update!(stock_status: "out_of_stock")
      available = create(:product, workspace: workspace, name: "Brownie Box")

      get new_workspace_post_creative_path(**slug, post_id: draft)

      expect(body_text).to include(available.name)
      expect(body_text).not_to include("Chocolate Truffle Cake")
    end

    it "keeps it out of a bulk plan too" do
      product.update!(stock_status: "out_of_stock")
      create(:product, workspace: workspace, name: "Brownie Box")
      template = create(:template)

      get edit_workspace_bulk_post_path(**slug, template_ids: [ template.id ])

      expect(body_text).to include("Brownie Box")
      expect(body_text).not_to include("Chocolate Truffle Cake")
    end

    it "leaves low stock available, because low is not none" do
      draft = create(:post, workspace: workspace, template: create(:template))
      product.update!(stock_status: "low_stock")

      get new_workspace_post_creative_path(**slug, post_id: draft)

      expect(body_text).to include("Chocolate Truffle Cake")
    end

    # Marking it sold out keeps it out of NEW posts, but the ones already in
    # the diary are the ones that will embarrass somebody.
    it "warns about a scheduled post that features it" do
      post = create(:post, workspace: workspace, subject: product,
                           scheduled_at: 3.days.from_now, scheduled_timezone: "Asia/Kolkata")
      post.update_columns(status: "scheduled")
      product.update!(stock_status: "out_of_stock")

      get workspace_root_path(**slug)

      expect(body_text).to include("features something you have marked unavailable")
      expect(body_text).to include("Chocolate Truffle Cake")
    end

    it "says nothing when the scheduled posts are all still available" do
      post = create(:post, workspace: workspace, subject: product,
                           scheduled_at: 3.days.from_now, scheduled_timezone: "Asia/Kolkata")
      post.update_columns(status: "scheduled")

      get workspace_root_path(**slug)

      expect(body_text).not_to include("marked unavailable")
    end
  end
end
