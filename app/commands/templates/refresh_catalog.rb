module Templates
  # Refreshes the catalogue's trend scores from whatever sources can currently
  # measure something.
  #
  # Two rules make this honest:
  #
  #   1. A category with no signal has its score CLEARED, not left behind. A
  #      stale score is worse than no score, because the gallery would keep
  #      calling something trending long after the evidence expired.
  #   2. A source that cannot measure contributes nothing and is recorded as
  #      such, so a silently broken feed looks different from a quiet week.
  class RefreshCatalog < ApplicationCommand
    # Scores older than this stop counting as evidence.
    FRESHNESS = 48.hours

    def initialize(sources: nil, now: Time.current)
      @sources = sources || TrendSource::Registry.available
      @now = now
    end

    def call
      measuring = @sources.select(&:available?)
      refresh = TemplateRefresh.start!(source: measuring.map(&:key).join(","))

      signals = gather(measuring, refresh)
      return Result.failure(refresh) if refresh.failed?

      updated = apply(signals)
      cleared = clear_unsupported(signals)

      refresh.finish!(added: 0, updated: updated, retired: cleared)
      Result.success(refresh)
    rescue StandardError => e
      refresh&.fail!("#{e.class}: #{e.message}")
      Result.failure(refresh)
    end

    private

    def gather(sources, refresh)
      sources.flat_map do |source|
        source.fetch_signals
      rescue SocialProvider::TransientError => e
        # A feed being briefly unreachable is not a catalogue failure; the run
        # completes with whatever the other sources measured.
        Rails.logger.warn(message: "trend source unavailable", source: source.key, error: e.class.name)
        []
      rescue SocialProvider::PermanentError => e
        refresh.fail!("#{source.key}: #{e.message}")
        []
      end
    end

    # One category can be reported by several sources; the strongest reading
    # wins rather than being averaged into something no source observed.
    def apply(signals)
      strongest = signals.group_by(&:content_category)
                         .transform_values { |group| group.max_by(&:score) }

      strongest.sum do |category, signal|
        Template.live.in_category(category)
                .update_all(trend_score: signal.score, trend_scored_at: @now, updated_at: @now)
      end
    end

    def clear_unsupported(signals)
      measured = signals.map(&:content_category).uniq

      scope = Template.where.not(trend_score: nil)
      scope = scope.where.not(content_category: measured) if measured.any?

      # Also clears scores that have simply gone stale.
      stale = Template.where.not(trend_score: nil).where(trend_scored_at: ...@now - FRESHNESS)

      (scope.to_a | stale.to_a).each do |template|
        template.update_columns(trend_score: nil, trend_scored_at: nil, updated_at: @now)
      end.size
    end
  end
end
