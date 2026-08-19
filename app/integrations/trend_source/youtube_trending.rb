module TrendSource
  # YouTube's own trending chart for India.
  #
  # This is the only genuinely free, official, no-approval trending feed of the
  # seven platforms Prachar supports. Meta publishes no trending endpoint at
  # all, and TikTok's Research API is restricted, so nothing equivalent exists
  # for Instagram, Facebook or TikTok.
  #
  # What it can honestly tell us: which broad content categories are
  # over-represented in India's chart today. It cannot tell us that a
  # particular Prachar style is trending, and this class does not pretend
  # otherwise -- it emits category-level signals and the refresh maps them onto
  # our own catalogue.
  class YoutubeTrending < Adapter
    ENDPOINT = "https://www.googleapis.com/youtube/v3/videos".freeze
    REGION = "IN".freeze
    SAMPLE_SIZE = 50

    # YouTube's own category ids mapped onto Prachar's content categories. Only
    # categories with a defensible reading are mapped; the rest are ignored
    # rather than forced into a bucket.
    CATEGORY_MAP = {
      "26" => "tips",                # Howto & Style
      "22" => "behind_the_scenes",   # People & Blogs
      "24" => "reels_style",         # Entertainment
      "27" => "educational",         # Education
      "19" => "festive",             # Travel & Events
      "20" => "product_showcase"     # Gaming -- high-production showcase format
    }.freeze

    def available? = api_key.present?

    def attribution = "Trending on YouTube in India"

    def fetch_signals
      unavailable!("YouTube trending needs YOUTUBE_API_KEY to be set") unless available?

      items = fetch_chart
      return [] if items.empty?

      counts = items.filter_map { |item| CATEGORY_MAP[item.dig("snippet", "categoryId")] }.tally
      return [] if counts.empty?

      busiest = counts.values.max

      counts.map do |category, count|
        TrendSignalDto.new(
          content_category: category,
          # Relative to the strongest category in the same chart, so the score
          # says "how prominent among today's trending videos", nothing more.
          score: ((count.to_f / busiest) * 100).round,
          sample_size: items.size,
          evidence: "#{count} of #{items.size} videos trending in India today"
        )
      end
    end

    private

    def api_key = ENV["YOUTUBE_API_KEY"].presence

    def fetch_chart
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(
        part: "snippet", chart: "mostPopular", regionCode: REGION,
        maxResults: SAMPLE_SIZE, key: api_key
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body).fetch("items", [])
      when Net::HTTPTooManyRequests, Net::HTTPServerError
        raise SocialProvider::TransientError.new("YouTube trending is unavailable", code: response.code)
      else
        # A bad key or an exhausted quota will not fix itself on retry.
        raise SocialProvider::PermanentError.new(
          "YouTube trending refused the request", code: response.code
        )
      end
    rescue JSON::ParserError => e
      raise SocialProvider::PermanentError.new("YouTube trending returned unreadable data: #{e.class}")
    rescue Timeout::Error, Errno::ECONNRESET, SocketError => e
      raise SocialProvider::TransientError.new("Could not reach YouTube: #{e.class}")
    end
  end
end
