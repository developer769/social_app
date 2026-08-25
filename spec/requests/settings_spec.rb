require "rails_helper"

RSpec.describe "Settings" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }

  describe "the hub" do
    it "renders every section" do
      get workspace_settings_root_path(**slug)

      expect(response).to have_http_status(:ok)
      SettingsMenu.entries.each do |entry|
        # Titles containing "&" are escaped in the rendered page.
        expect(response.body).to include(ERB::Util.html_escape(entry.title))
      end
    end

    # A card that goes nowhere is worse than one that explains itself; the
    # sidebar already made that mistake.
    # The hub offered both "Posting preferences" and "Publishing defaults",
    # pointing at the same URL. Somebody clicking the second one landed on the
    # first and reasonably assumed it was broken.
    it "never offers two cards that go to the same place" do
      destinations = SettingsMenu.entries.filter_map(&:route)

      expect(destinations).to eq(destinations.uniq)
    end

    it "keeps publishing defaults findable by name on the one card that has them" do
      get workspace_settings_root_path(**slug)

      body = response.body.gsub(/\s+/, " ")
      expect(body).to include("first comment, links and hashtags")
      expect(body).not_to include("Publishing defaults")
    end

    it "says what an unavailable section is waiting on" do
      get workspace_settings_root_path(**slug)

      SettingsMenu.entries.reject(&:available?).each do |entry|
        expect(response.body).to include(entry.waiting_on)
      end
    end
  end

  describe "every page renders" do
    %i[
      workspace_settings_root_path workspace_settings_business_path
      workspace_settings_catalog_path workspace_settings_connections_path
      workspace_settings_team_index_path workspace_settings_security_path
      workspace_settings_billing_path workspace_settings_posting_preferences_path
      workspace_settings_brand_kit_path workspace_settings_notifications_path
    ].each do |helper|
      it helper.to_s do
        get public_send(helper, **slug)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "business profile" do
    it "saves without moving onboarding" do
      workspace.update!(onboarding_step: "completed")

      patch workspace_settings_business_path(**slug), params: {
        business_setup: { business_name: "Renamed Bakes", category: "Patisserie" },
        goals: %w[increase_sales]
      }

      expect(workspace.reload.name).to eq("Renamed Bakes")
      expect(workspace.onboarding_step).to eq("completed")
    end
  end

  describe "posting preferences" do
    it "stores voice, style and schedule" do
      patch workspace_settings_posting_preferences_path(**slug), params: {
        posting_preference: {
          brand_voice: "Warm and trustworthy", caption_style: "storytelling",
          hashtag_style: "minimal", emoji_level: "moderate", posts_per_week: 4,
          preferred_time: "18:30", preferred_days: %w[1 3 5],
          brand_keywords_text: "Freshly baked, Handmade",
          avoid_terms_text: "Discount, Cheap"
        }
      }

      preference = workspace.reload.posting_preference
      expect(preference.caption_style).to eq("storytelling")
      expect(preference.preferred_days).to eq([ 1, 3, 5 ])
      expect(preference.brand_keywords).to eq([ "Freshly baked", "Handmade" ])
      expect(preference.avoid_terms).to eq([ "Discount", "Cheap" ])
      expect(preference.schedule_summary).to include("4 posts a week")
    end

    it "refuses a frequency nobody could sustain" do
      patch workspace_settings_posting_preferences_path(**slug), params: {
        posting_preference: { posts_per_week: 500, preferred_time: "10:00" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "brand kit" do
    it "stores colours and typography" do
      patch workspace_settings_brand_kit_path(**slug), params: {
        brand_kit: { primary_color: "#341044", accent_color: "#F8DCA8", heading_font: "Fraunces" }
      }

      kit = workspace.reload.brand_kit
      expect(kit.primary_color).to eq("#341044")
      expect(kit.colors.keys).to include("Primary", "Accent")
    end

    it "refuses something that is not a colour" do
      patch workspace_settings_brand_kit_path(**slug), params: {
        brand_kit: { primary_color: "purple-ish" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "notification preferences" do
    it "belongs to the person, not the workspace" do
      teammate = create(:user)
      create(:workspace_membership, workspace: workspace, user: teammate)

      patch workspace_settings_notifications_path(**slug),
            params: { notification_preference: { email_weekly_summary: "0" } }

      expect(NotificationPreference.for(workspace: workspace, user: owner).email_weekly_summary).to be(false)
      expect(NotificationPreference.for(workspace: workspace, user: teammate).email_weekly_summary).to be(true)
    end
  end

  describe "security" do
    it "changes the password and signs out every other device" do
      other = Session.start!(user: owner)

      patch workspace_settings_security_path(**slug), params: {
        user: { current_password: "correct-horse-battery", password: "a-brand-new-passphrase" }
      }

      expect(owner.reload.authenticate("a-brand-new-passphrase")).to be_truthy
      expect(other.reload.revoked_at).to be_present
    end

    it "refuses without the current password" do
      patch workspace_settings_security_path(**slug), params: {
        user: { current_password: "wrong", password: "a-brand-new-passphrase" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(owner.reload.authenticate("correct-horse-battery")).to be_truthy
    end

    it "revokes one device without touching the others" do
      other = Session.start!(user: owner)

      delete workspace_settings_security_session_path(**slug, id: other)

      expect(other.reload.revoked_at).to be_present
      expect(Current.session&.revoked_at).to be_nil
    end

    it "cannot revoke someone else's session" do
      stranger_session = Session.start!(user: create(:user))

      # Sessions are looked up through current_user, so another person's id is
      # simply absent and the workspace scoping renders its not-found page.
      delete workspace_settings_security_session_path(**slug, id: stranger_session)

      expect(response).to have_http_status(:not_found)
      expect(stranger_session.reload.revoked_at).to be_nil
    end
  end

  describe "billing" do
    it "reports usage counted from real records" do
      load Rails.root.join("db/seeds/plans.rb")
      Billing::StartTrial.call(workspace: workspace, plan: Plan.find_by(code: "basic", interval: "month"), actor: owner)
      create(:post, workspace: workspace)

      get workspace_settings_billing_path(**slug)

      expect(response.body).to include("Usage")
      expect(response.body).to include("Posts this month")
    end

    # A meter for something that cannot be used yet would imply it works.
    it "marks generation as unavailable rather than showing a zeroed meter" do
      load Rails.root.join("db/seeds/plans.rb")
      Billing::StartTrial.call(workspace: workspace, plan: Plan.first, actor: owner)

      get workspace_settings_billing_path(**slug)

      expect(response.body).to include("Not available yet")
    end
  end

  describe "tenant isolation" do
    it "cannot open another workspace's settings" do
      other = create(:workspace)
      create(:workspace_membership, workspace: other, user: create(:user))

      get workspace_settings_root_path(workspace_slug: other.slug)

      expect(response).to have_http_status(:not_found)
    end
  end
end
