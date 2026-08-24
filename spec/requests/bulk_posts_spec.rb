require "rails_helper"

RSpec.describe "Planning a month in bulk" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner, timezone: "Asia/Kolkata") }
  let!(:preference) do
    create(:posting_preference, workspace: workspace, preferred_days: [ 1, 3, 5 ],
                                posts_per_week: 5, preferred_time: "10:00")
  end
  let!(:product) { create(:product, workspace: workspace, name: "Chocolate Truffle Cake") }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def photo(name = "Weekend Indulgence") = create(:template, name: name, media_format: "image")
  def video(name = "Reel Style") = create(:template, :video, name: name)

  describe "choosing styles" do
    it "offers live styles to choose from" do
      photo("Weekend Indulgence")

      get new_workspace_bulk_post_path(**slug)

      expect(body_text).to include("Plan a month")
      expect(body_text).to include("Weekend Indulgence")
    end

    it "leaves out a retired style" do
      create(:template, :retired, name: "Old Style")

      get new_workspace_bulk_post_path(**slug)

      expect(body_text).not_to include("Old Style")
    end

    # Spec 30. Nothing here can generate video, so offering video styles without
    # saying so would promise something no provider can do.
    it "says video styles are scheduled rather than made" do
      get new_workspace_bulk_post_path(**slug)

      expect(body_text).to include("Video styles are scheduled, not made")
      expect(body_text).to include("waits for you to add your own file")
    end
  end

  describe "reviewing the batch" do
    it "shows the day and time each one would go out" do
      a, b = photo("First"), photo("Second")

      get edit_workspace_bulk_post_path(**slug, template_ids: [ a.id, b.id ])

      expect(body_text).to include("First").and include("Second")
      expect(body_text).to match(/Goes out \w{3} \d+ \w{3} at 10:00 AM/)
    end

    it "marks a video style as needing the owner's own file" do
      get edit_workspace_bulk_post_path(**slug, template_ids: [ video.id ])

      expect(body_text).to include("You add the video")
    end

    # Arithmetic over the days they chose, not a model deciding anything.
    it "says plainly how the dates were worked out" do
      get edit_workspace_bulk_post_path(**slug, template_ids: [ photo.id ])

      expect(body_text).to include("Spread across your posting days at your usual time")
      expect(body_text).to include("Nothing lands on a slot that already has a post")
    end

    it "says captions are the owner's to write" do
      get edit_workspace_bulk_post_path(**slug, template_ids: [ photo.id ])

      expect(body_text).to include("Prachar cannot write captions")
    end

    it "sends an owner with no catalog to the catalog first" do
      product.destroy!

      get edit_workspace_bulk_post_path(**slug, template_ids: [ photo.id ])

      expect(body_text).to include("Nothing in your catalog yet")
    end

    it "refuses an empty batch" do
      get edit_workspace_bulk_post_path(**slug, template_ids: [])

      expect(response).to redirect_to(new_workspace_bulk_post_path(**slug))
      expect(flash[:alert]).to include("at least one style")
    end

    # Sundays only, one a week, is about seventeen slots inside the planner's
    # horizon -- so twenty is genuinely more than the chosen days can hold.
    it "warns when the chosen days cannot fit them all" do
      preference.update!(preferred_days: [ 0 ], posts_per_week: 1)
      templates = Array.new(20) { photo(SecureRandom.hex(4)) }

      get edit_workspace_bulk_post_path(**slug, template_ids: templates.map(&:id))

      expect(body_text).to include("Add more days or post more often")
    end
  end

  describe "scheduling the batch" do
    def schedule(templates, subjects: nil)
      post workspace_bulk_post_path(**slug),
           params: { template_ids: templates.map(&:id),
                     subjects: subjects || templates.to_h { |t| [ t.id.to_s, "Product:#{product.id}" ] } }
    end

    it "creates every post, already scheduled" do
      templates = [ photo("One"), photo("Two"), photo("Three") ]

      expect { schedule(templates) }.to change(Post, :count).by(3)

      expect(workspace.posts.pluck(:status).uniq).to eq([ "scheduled" ])
      expect(workspace.posts.pluck(:scheduled_at)).to all(be > Time.current)
    end

    it "gives each post its own slot rather than stacking them" do
      schedule([ photo("One"), photo("Two"), photo("Three") ])

      times = workspace.posts.pluck(:scheduled_at)
      expect(times.uniq.size).to eq(3)
    end

    it "records what each post features" do
      schedule([ photo ])

      expect(workspace.posts.first.subject).to eq(product)
    end

    # No text generator exists, so the caption is the product's own name and
    # the owner edits it.
    it "starts the caption from the product name" do
      schedule([ photo ])

      expect(workspace.posts.first.caption).to eq("Chocolate Truffle Cake")
    end

    it "carries over the defaults the owner set themselves" do
      preference.update!(default_call_to_action: "Order on WhatsApp",
                         default_link_url: "https://anayabakes.test/order")

      schedule([ photo ])

      created = workspace.posts.first
      expect(created.call_to_action).to eq("Order on WhatsApp")
      expect(created.link_url).to eq("https://anayabakes.test/order")
    end

    it "asks for pictures for every photo post" do
      expect { schedule([ photo("One"), photo("Two") ]) }
        .to change(CreativeRequest, :count).by(2)
    end

    # Spec 30 again: video is scheduled, never requested from a provider that
    # would refuse it.
    it "asks for nothing for a video post" do
      expect { schedule([ video ]) }.not_to change(CreativeRequest, :count)

      expect(workspace.posts.first).to be_scheduled
    end

    it "says how many need the owner's own video" do
      schedule([ photo("One"), video("Reel") ])

      expect(flash[:notice]).to include("1 post needs your own video")
      expect(flash[:notice]).to include("Prachar cannot make video yet")
    end

    it "reports the range it scheduled across" do
      schedule([ photo("One"), photo("Two") ])

      expect(flash[:notice]).to match(/2 posts scheduled from \d+ \w{3} to \d+ \w{3}/)
    end

    it "records the batch in the audit trail" do
      expect { schedule([ photo ]) }
        .to change { AuditEvent.where(action: "posts.bulk_created").count }.by(1)
    end

    it "targets the connected accounts that can carry it" do
      create(:social_account, workspace: workspace, provider: "instagram")
      create(:social_account, workspace: workspace, provider: "facebook")

      schedule([ photo ])

      expect(workspace.posts.first.providers).to contain_exactly("instagram", "facebook")
    end

    # YouTube takes video and not pictures, so a photo batch must not target it.
    it "does not target a platform that cannot carry the format" do
      create(:social_account, workspace: workspace, provider: "youtube")

      schedule([ photo ])

      expect(workspace.posts.first.providers).to be_empty
    end

    it "refuses a batch with nothing chosen" do
      post workspace_bulk_post_path(**slug), params: { template_ids: [] }

      expect(flash[:alert]).to include("at least one style")
      expect(Post.count).to eq(0)
    end

    # Spec 7.
    it "ignores a product belonging to another workspace" do
      theirs = create(:product, workspace: create(:workspace), name: "Someone else's cake")
      template = photo

      schedule([ template ], subjects: { template.id.to_s => "Product:#{theirs.id}" })

      expect(workspace.posts.first.subject).to be_nil
    end

    it "ignores a style id that is not live" do
      retired = create(:template, :retired)

      post workspace_bulk_post_path(**slug),
           params: { template_ids: [ retired.id ], subjects: {} }

      expect(flash[:alert]).to include("no longer available")
      expect(Post.count).to eq(0)
    end
  end
end
