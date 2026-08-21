require "rails_helper"

# NOTE: the draft is deliberately not called `post` here -- that name is the
# HTTP verb in a request spec, and shadowing it makes every POST in the file
# silently call the factory instead.
RSpec.describe "Generating a creative" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }
  let(:template) { create(:template, name: "Weekend Indulgence") }
  let!(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }
  let(:draft) { create(:post, workspace: workspace, template: template) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "choosing what to feature" do
    it "offers the workspace's own catalog" do
      service = create(:service, workspace: workspace, name: "Custom Birthday Cake")

      get new_workspace_post_creative_path(**slug, post_id: draft)

      expect(response.body).to include(product.name).and include(service.name)
    end

    # Spec 2. There is no field here for text to place on the picture, because
    # there would be no way to position or correct it afterwards.
    it "offers no way to put words onto the picture" do
      get new_workspace_post_creative_path(**slug, post_id: draft)

      expect(response.body).to include("cannot put your own words onto the picture")
      expect(response.body).not_to match(/name="(overlay|caption_text|text_position|font)"/)
    end

    it "sends an owner with an empty catalog to the catalog first" do
      product.destroy!

      get new_workspace_post_creative_path(**slug, post_id: draft)

      expect(response.body).to include("Nothing in your catalog yet")
    end
  end

  describe "starting a generation" do
    it "records what the post features and queues every variant" do
      expect {
        post workspace_post_creative_path(**slug, post_id: draft),
             params: { subject: "Product:#{product.id}" }
      }.to change(CreativeOutput, :count).by(3)

      expect(draft.reload.subject).to eq(product)
      expect(response).to redirect_to(workspace_post_creative_path(**slug, post_id: draft))
    end

    it "asks for a subject rather than generating a picture of nothing" do
      post workspace_post_creative_path(**slug, post_id: draft), params: { subject: "" }

      expect(flash[:alert]).to eq("Choose what this post should feature first.")
      expect(CreativeRequest.count).to eq(0)
    end

    # Spec 30. A video style is refused with the reason, not queued and then
    # quietly failed three times over.
    it "says plainly that video is not available yet" do
      draft.update!(template: create(:template, :video))

      post workspace_post_creative_path(**slug, post_id: draft),
           params: { subject: "Product:#{product.id}" }

      expect(flash[:alert]).to eq("Video generation is not available yet.")
      expect(CreativeRequest.count).to eq(0)
    end

    # Spec 7. The id arrives from the browser, so it is looked up through the
    # workspace and simply is not found when it belongs to somebody else.
    it "ignores a product id belonging to another workspace" do
      theirs = create(:product, workspace: create(:workspace), name: "Another Bakery Cake")

      post workspace_post_creative_path(**slug, post_id: draft),
           params: { subject: "Product:#{theirs.id}" }

      expect(draft.reload.subject).to be_nil
      expect(CreativeRequest.count).to eq(0)
    end
  end

  describe "the results screen" do
    let(:generation) do
      create(:creative_request, :with_outputs, workspace: workspace, post: draft, template: template)
    end

    it "counts progress from real rows while it works" do
      generation.creative_outputs.first.succeed!(media_asset: create(:media_asset, workspace: workspace))

      get workspace_post_creative_path(**slug, post_id: draft)

      expect(response.body).to include("1 of 3")
    end

    context "when the versions are ready" do
      before do
        generation.creative_outputs.each do |output|
          output.succeed!(media_asset: create(:media_asset, workspace: workspace),
                          metadata: { "watermarked" => true })
        end
        generation.settle!
      end

      # Spec 27. These look like finished creatives and are not, so the screen
      # says so rather than letting the watermark carry the whole message.
      it "says plainly that these are samples" do
        get workspace_post_creative_path(**slug, post_id: draft)

        expect(response.body).to include("These are samples")
        expect(response.body).to include("cannot be published")
      end

      # Spec 2. When a picture is wrong, these three are the only offers.
      it "offers only regenerate, another style, or your own picture" do
        get workspace_post_creative_path(**slug, post_id: draft)

        expect(response.body).to include("Try again")
          .and include("Choose another style")
          .and include("Use my own picture instead")
        expect(response.body).not_to match(/\b(crop|filter|trim|sticker|background remov)/i)
      end

      it "attaches the chosen version to the post" do
        chosen = generation.creative_outputs.last

        post workspace_creative_request_selections_path(
          **slug, creative_request_id: generation.id, id: chosen.id
        )

        expect(generation.reload.selected_output).to eq(chosen)
        expect(draft.reload.primary_media).to eq(chosen.media_asset)
      end

      # Choosing twice must replace, not accumulate.
      it "leaves one picture attached after changing your mind" do
        generation.creative_outputs.first(2).each do |output|
          post workspace_creative_request_selections_path(
            **slug, creative_request_id: generation.id, id: output.id
          )
        end

        expect(draft.reload.post_media.count).to eq(1)
      end
    end

    it "explains a variant that could not be made instead of leaving a gap" do
      generation.creative_outputs.each { |output| output.fail!(outcome: "refused", message: "no") }
      generation.settle!

      get workspace_post_creative_path(**slug, post_id: draft)

      expect(response.body).to include("The generator would not make this one")
    end

    it "will not choose a version that is not ready" do
      unfinished = generation.creative_outputs.first

      post workspace_creative_request_selections_path(
        **slug, creative_request_id: generation.id, id: unfinished.id
      )

      expect(generation.reload.selected_output).to be_nil
      expect(flash[:alert]).to match(/not ready/)
    end
  end

  # Spec 7. A generation belongs to one workspace and is invisible from another,
  # slug or no slug.
  describe "tenant isolation" do
    let(:other_workspace) { create(:workspace) }
    let(:theirs) do
      create(:creative_request, :with_outputs, workspace: other_workspace,
                                               post: create(:post, workspace: other_workspace))
    end

    it "cannot open another workspace's generation" do
      get workspace_post_creative_path(**slug, post_id: theirs.post_id)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot choose a version from another workspace's generation" do
      post workspace_creative_request_selections_path(
        **slug, creative_request_id: theirs.id, id: theirs.creative_outputs.first.id
      )

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.selected_output).to be_nil
    end
  end
end
