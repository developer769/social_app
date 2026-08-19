require "rails_helper"

RSpec.describe Templates::RefreshCatalog do
  def measuring_source(category:, score:, key: "test_source")
    Class.new(TrendSource::Adapter) do
      define_method(:key) { key }
      define_method(:available?) { true }
      define_method(:attribution) { "Measured" }
      define_method(:fetch_signals) do
        [ TrendSource::TrendSignalDto.new(content_category: category, score: score, sample_size: 50) ]
      end
    end.new
  end

  def failing_source(error)
    Class.new(TrendSource::Adapter) do
      define_method(:key) { "failing" }
      define_method(:available?) { true }
      define_method(:fetch_signals) { raise error }
    end.new
  end

  let!(:behind_the_scenes) { create(:template, content_category: "behind_the_scenes") }
  let!(:festive) { create(:template, content_category: "festive") }

  describe "with nothing able to measure" do
    it "completes cleanly and scores nothing" do
      result = described_class.call(sources: [ TrendSource::CuratedSource.new ])

      expect(result).to be_success
      expect(result.value).to be_complete
      expect(Template.where.not(trend_score: nil)).to be_empty
    end

    # Curation is an editorial choice. Letting it produce a score would let the
    # gallery call something trending that nobody counted.
    it "treats curation as evidence of nothing" do
      expect(TrendSource::CuratedSource.new.fetch_signals).to be_empty
    end
  end

  describe "with a measured signal" do
    it "scores only the templates in the measured category" do
      described_class.call(sources: [ measuring_source(category: "behind_the_scenes", score: 88) ])

      expect(behind_the_scenes.reload.trend_score).to eq(88)
      expect(festive.reload.trend_score).to be_nil
    end

    it "lets the gallery speak about trends only once something is scored" do
      expect(behind_the_scenes.trend_ranked?).to be(false)

      described_class.call(sources: [ measuring_source(category: "behind_the_scenes", score: 70) ])

      expect(behind_the_scenes.reload.trend_ranked?).to be(true)
    end

    it "keeps the strongest reading when two sources disagree, rather than averaging" do
      described_class.call(sources: [
        measuring_source(category: "festive", score: 40, key: "a"),
        measuring_source(category: "festive", score: 90, key: "b")
      ])

      expect(festive.reload.trend_score).to eq(90)
    end
  end

  describe "clearing" do
    before { described_class.call(sources: [ measuring_source(category: "festive", score: 90) ]) }

    # A stale score is worse than no score: the gallery would keep calling
    # something trending long after the evidence expired.
    it "clears a score once its category stops being measured" do
      described_class.call(sources: [ measuring_source(category: "behind_the_scenes", score: 60) ])

      expect(festive.reload.trend_score).to be_nil
    end

    it "clears a score that has simply gone stale" do
      festive.update_columns(trend_scored_at: 3.days.ago)

      described_class.call(sources: [ measuring_source(category: "festive", score: 90) ])

      expect(festive.reload.trend_scored_at).to be_within(1.minute).of(Time.current)
    end
  end

  describe "when a source misbehaves" do
    it "completes with what the other sources measured when one is briefly unreachable" do
      result = described_class.call(sources: [
        failing_source(SocialProvider::TransientError.new("network")),
        measuring_source(category: "festive", score: 55)
      ])

      expect(result).to be_success
      expect(festive.reload.trend_score).to eq(55)
    end

    it "records a failure rather than looking like a quiet week" do
      result = described_class.call(sources: [ failing_source(SocialProvider::PermanentError.new("bad key")) ])

      expect(result).to be_failure
      expect(result.error).to be_failed
      expect(result.error.error_message).to include("bad key")
    end
  end

  describe TrendSource::YoutubeTrending do
    it "reports itself unavailable without a key instead of returning nothing" do
      expect(described_class.new).not_to be_available
      expect { described_class.new.fetch_signals }
        .to raise_error(SocialProvider::PermanentError, /YOUTUBE_API_KEY/)
    end

    it "labels itself as the specific chart it reads" do
      expect(described_class.new.attribution).to eq("Trending on YouTube in India")
    end
  end
end
