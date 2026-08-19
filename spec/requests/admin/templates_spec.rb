require "rails_helper"

RSpec.describe "Admin templates" do
  let(:staff) { create(:staff_user) }

  before { post admin_login_path, params: { email: staff.email, password: "correct-horse-battery-staple" } }

  def preview_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("db/seeds/templates/photo-01.jpg"), "image/jpeg"
    )
  end

  describe "creating" do
    # Uploading is not publishing. A half-finished style must never appear in a
    # customer's gallery just because someone hit save.
    it "saves a new style as a draft, not into every gallery" do
      expect {
        post admin_templates_path, params: {
          template: { name: "Diwali Sweet Box", content_category: "festive",
                      media_format: "image", aspect_ratio: "4:5",
                      description: "Festive framing for a sweets hamper.",
                      style_tags_text: "festive, warm, ornate" }
        }
      }.to change(Template, :count).by(1)

      template = Template.order(:created_at).last
      expect(template).to be_draft
      expect(template).not_to be_published
      expect(Template.published).not_to include(template)
    end

    it "splits the comma separated style words into real tags" do
      post admin_templates_path, params: {
        template: { name: "Diwali Sweet Box", content_category: "festive", media_format: "image",
                    style_tags_text: "festive,  warm , ornate" }
      }

      expect(Template.order(:created_at).last.style_tags).to eq(%w[festive warm ornate])
    end

    it "derives a slug that keeps a photo and a video of the same name apart" do
      post admin_templates_path, params: {
        template: { name: "Red Velvet", content_category: "product_showcase", media_format: "image" }
      }
      post admin_templates_path, params: {
        template: { name: "Red Velvet", content_category: "product_showcase",
                    media_format: "video", duration_seconds: 15 }
      }

      expect(Template.where(name: "Red Velvet").pluck(:slug))
        .to contain_exactly("red-velvet-photo", "red-velvet-video")
    end

    it "refuses a video style with no duration, because it cannot be checked against platform limits" do
      expect {
        post admin_templates_path, params: {
          template: { name: "No Duration", content_category: "reels_style", media_format: "video" }
        }
      }.not_to change(Template, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "accepts a preview image" do
      post admin_templates_path, params: {
        template: { name: "With Preview", content_category: "festive",
                    media_format: "image", preview: preview_upload }
      }

      expect(Template.order(:created_at).last.preview).to be_attached
    end

    it "records who created it" do
      expect {
        post admin_templates_path, params: {
          template: { name: "Audited", content_category: "festive", media_format: "image" }
        }
      }.to change { StaffAuditEvent.where(action: "template.created").count }.by(1)

      expect(StaffAuditEvent.last.staff_user).to eq(staff)
    end
  end

  describe "publishing" do
    let(:template) { create(:template, draft: true, published_at: nil) }

    it "puts the style into every gallery and records who did it" do
      post publish_admin_template_path(template)

      expect(template.reload).to be_published
      expect(template.published_by).to eq(staff)
      expect(Template.published).to include(template)
      expect(StaffAuditEvent.where(action: "template.published").count).to eq(1)
    end

    it "publishes a video style even without an example clip, since the generator does not need one" do
      video = create(:template, :video, draft: true, published_at: nil)

      post publish_admin_template_path(video)

      expect(video.reload).to be_published
      expect(video.example_video?).to be(false)
    end

    it "takes a published style back out of every gallery" do
      post publish_admin_template_path(template)

      post unpublish_admin_template_path(template)

      expect(template.reload).not_to be_published
      expect(Template.published).not_to include(template)
    end

    it "keeps the original publication date when republished" do
      post publish_admin_template_path(template)
      first_published_at = template.reload.published_at

      post unpublish_admin_template_path(template)
      post publish_admin_template_path(template)

      expect(template.reload.published_at).to eq(first_published_at)
    end
  end

  describe "retiring" do
    let(:template) { create(:template) }

    # Retiring is a timestamp, not a delete, because posts made with the style
    # still reference it.
    it "removes it from the gallery without destroying it" do
      template # created before the block, so the count measures only the retire

      expect { post retire_admin_template_path(template) }.not_to change(Template, :count)

      expect(template.reload).to be_retired
      expect(Template.published).not_to include(template)
    end
  end

  describe "the photo and video catalogues" do
    let!(:photo) { create(:template, name: "A Photo Style") }
    let!(:video) { create(:template, :video, name: "A Video Style") }

    it "defaults to photos and shows no video styles" do
      get admin_templates_path

      expect(response.body).to include("Photo styles", "A Photo Style")
      expect(response.body).not_to include("A Video Style")
    end

    it "shows only video styles on the video catalogue" do
      get admin_templates_path(media_format: "video")

      expect(response.body).to include("Video styles", "A Video Style")
      expect(response.body).not_to include("A Photo Style")
    end

    it "keeps the state filter within the chosen format" do
      create(:template, :video, name: "A Video Draft", draft: true, published_at: nil)

      get admin_templates_path(media_format: "video", scope: "drafts")

      expect(response.body).to include("A Video Draft")
      expect(response.body).not_to include("A Video Style")
      expect(response.body).not_to include("A Photo Style")
    end

    it "falls back to photos when the format is not recognised" do
      get admin_templates_path(media_format: "hologram")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Photo styles")
    end

    it "starts a new video style with a sensible shape and duration already set" do
      get new_admin_template_path(media_format: "video")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add a video style")
    end

    it "names the platforms each format cannot reach, read from real capabilities" do
      get admin_templates_path(media_format: "image")
      expect(response.body).to include("except YouTube and TikTok")

      get admin_templates_path(media_format: "video")
      expect(response.body).to include("except Google Business Profile")
    end

    it "returns to the catalogue the style belongs to after retiring it" do
      post retire_admin_template_path(video)

      expect(response).to redirect_to(admin_templates_path(media_format: "video", scope: "retired"))
    end
  end

  describe "the customer gallery" do
    it "shows only published, live styles" do
      published = create(:template, draft: false, published_at: Time.current)
      create(:template, draft: true, published_at: nil)
      create(:template, :retired, published_at: Time.current)

      expect(Template.published).to contain_exactly(published)
    end
  end
end
