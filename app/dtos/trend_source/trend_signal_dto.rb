module TrendSource
  # Evidence that one content category is doing unusually well right now.
  #
  # score is 0-100 and is only ever derived from something counted. A source
  # that cannot measure a category simply does not emit a signal for it, rather
  # than emitting zero (spec 27).
  class TrendSignalDto < ApplicationDto
    attribute :content_category, :score, :sample_size, :observed_at, :evidence

    def initialize(content_category:, score:, sample_size:, observed_at: nil, evidence: nil)
      @content_category = content_category.to_s
      @score = score.to_i.clamp(0, 100)
      @sample_size = sample_size.to_i
      @observed_at = observed_at || Time.current
      @evidence = evidence
      freeze
    end
  end
end
