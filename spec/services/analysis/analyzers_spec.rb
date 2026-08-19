require "rails_helper"

RSpec.describe "Brand analysis analyzers" do
  let(:workspace) { create(:workspace) }

  describe Analysis::ProfileHealth do
    it "scores only what has actually been filled in" do
      create(:brand_profile, workspace: workspace, category: "Bakery",
             business_type: "small_business", city: "Delhi, India")

      outcome = described_class.call(workspace: workspace.reload)

      expect(outcome.outcome).to eq("analysed")
      expect(outcome.result[:complete]).to include("Business category", "Location")
      expect(outcome.result[:missing]).to include("Logo", "About your business")
    end

    it "scores zero for an untouched workspace rather than erroring" do
      outcome = described_class.call(workspace: workspace)

      expect(outcome.result[:score]).to eq(0)
    end

    it "reaches one hundred only when everything is present" do
      create(:brand_profile, workspace: workspace, category: "Bakery", business_type: "small_business",
             contact_email: "hello@anayabakes.test", phone: "+919876543210",
             city: "Delhi, India", about: "Handcrafted bakes.")
      create(:brand_goal, workspace: workspace)
      create(:brand_tone, workspace: workspace)
      create(:product, workspace: workspace)
      workspace.brand_profile.logo.attach(
        io: StringIO.new("fake"), filename: "logo.png", content_type: "image/png"
      )

      expect(described_class.call(workspace: workspace.reload).result[:score]).to eq(100)
    end
  end

  describe Analysis::ContentCategories do
    it "derives categories from the catalog and ranks them" do
      create(:product, workspace: workspace, category: "Cakes")
      create(:product, workspace: workspace, category: "Cakes")
      create(:service, workspace: workspace, category: "Events")

      outcome = described_class.call(workspace: workspace.reload)

      expect(outcome.outcome).to eq("analysed")
      expect(outcome.result[:categories].first).to eq(name: "Cakes", items: 2)
    end

    it "says what is missing instead of returning an empty list" do
      outcome = described_class.call(workspace: workspace)

      expect(outcome.outcome).to eq("insufficient_data")
      expect(outcome.result[:reason]).to include("Add products or services")
    end
  end

  describe Analysis::BrandVoice do
    it "reports the tones the owner chose, and says where they came from" do
      create(:brand_tone, workspace: workspace, tone: "friendly")

      outcome = described_class.call(workspace: workspace.reload)

      expect(outcome.result[:tones]).to eq(%w[Friendly])
      expect(outcome.result[:source]).to eq("stated_preference")
    end
  end

  # The point of these: they must never return a number when they have no data.
  describe "performance analyzers without a real connection" do
    [ Analysis::TopContent, Analysis::PostingFrequency,
      Analysis::AudienceEngagement, Analysis::BestPostingTimes ].each do |analyzer|
      it "#{analyzer} asks for a connection rather than inventing a figure" do
        outcome = analyzer.call(workspace: workspace)

        expect(outcome.outcome).to eq("not_supported")
        expect(outcome.result[:reason]).to include("Connect a social account")
        expect(outcome.result.keys).to eq([ :reason ])
      end

      it "#{analyzer} still refuses to invent figures when only mock accounts are connected" do
        Connections::ConnectAccount.call(
          workspace: workspace, provider: "instagram", actor: workspace.owner_user
        )

        outcome = analyzer.call(workspace: workspace.reload)

        expect(outcome.outcome).to eq("not_supported")
        expect(outcome.result[:reason]).to include("simulated")
      end
    end
  end
end
