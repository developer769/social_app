module TrendSource
  # Which sources feed the catalogue.
  #
  # Curation is always present. YouTube joins only when it has a key, and
  # reports itself unavailable rather than silently contributing nothing.
  module Registry
    SOURCES = {
      "curated" => CuratedSource,
      "youtube_trending" => YoutubeTrending
    }.freeze

    module_function

    def all = SOURCES.values.map(&:new)

    def available = all.select(&:available?)

    def find(key)
      klass = SOURCES[key.to_s]
      klass&.new
    end

    def keys = SOURCES.keys

    # True when at least one source can supply a measured signal, which is what
    # entitles the gallery to speak about trends at all.
    def any_measuring? = available.any? { |source| source.fetch_signals.any? rescue false }
  end
end
