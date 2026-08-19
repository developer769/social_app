module TrendSource
  # The editorial catalogue: a person decides what goes in, weekly.
  #
  # It deliberately emits NO signals. Curation is a considered choice, not a
  # measurement, so it must never produce a trend score -- that would let the
  # gallery say "trending" about something nobody counted.
  class CuratedSource < Adapter
    def available? = true

    def attribution = "Curated by Prachar"

    def fetch_signals = []
  end
end
