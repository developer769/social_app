module SocialProvider
  # Where each platform's OAuth lives, and what to ask it for.
  #
  # ============================================================================
  # EVERY VALUE BELOW MUST BE RE-CHECKED AGAINST THE PLATFORM'S LIVE
  # DOCUMENTATION BEFORE THAT PROVIDER GOES LIVE.
  #
  # These were written from published documentation and are the most volatile
  # facts in this codebase: platforms rename scopes, bump API versions and move
  # endpoints without notice. `verified_on: nil` means nobody has confirmed
  # this entry against the real docs yet. Set it to a date when you do, and
  # `OAuthConfig.unverified` will stop listing it.
  #
  # Getting one of these wrong does not fail quietly -- the authorisation
  # screen returns an error before a user ever grants anything -- so the cost
  # of an out-of-date value is a clear failure, not a silent one.
  # ============================================================================
  #
  # Credentials come from the environment, never from this file and never from
  # the repository, matching how every other secret in this application is
  # supplied (see docker-compose.prod.yml).
  module OAuthConfig
    Entry = Struct.new(
      :key, :authorize_url, :token_url, :scopes, :pkce, :authorize_params,
      :client_id_env, :client_secret_env, :verified_on,
      keyword_init: true
    ) do
      def pkce? = !!pkce
      def verified? = verified_on.present?
      def client_id = ENV[client_id_env].presence
      def client_secret = ENV[client_secret_env].presence

      # Both halves, or the flow cannot even start. A client id without a
      # secret gets you to the platform's consent screen and fails on the way
      # back, which is a confusing place to discover a missing variable.
      def configured? = client_id.present? && client_secret.present?
      def scope_string = scopes.join(scope_separator)

      # Google and Meta separate scopes with a space; Meta's older dialogs and
      # LinkedIn historically accepted commas. Space is correct per RFC 6749.
      def scope_separator = " "
    end

    def self.define(key, **attrs)
      Entry.new(key: key.to_s, scopes: [], pkce: false, authorize_params: {},
                client_id_env: "#{key.to_s.upcase}_CLIENT_ID",
                client_secret_env: "#{key.to_s.upcase}_CLIENT_SECRET",
                verified_on: nil, **attrs)
    end

    ALL = {
      # Instagram publishing runs through the Facebook Graph API: one Meta app,
      # one login, and the Instagram account must be Business or Creator and
      # linked to a Facebook Page. That is a property of the customer's
      # account, not of this configuration, and is the most common reason a
      # connection that "worked" cannot publish.
      "instagram" => define(:instagram,
        authorize_url: "https://www.facebook.com/v21.0/dialog/oauth",
        token_url: "https://graph.facebook.com/v21.0/oauth/access_token",
        scopes: %w[instagram_basic instagram_content_publish instagram_manage_comments
                   instagram_manage_insights pages_show_list pages_read_engagement
                   business_management],
        client_id_env: "META_CLIENT_ID", client_secret_env: "META_CLIENT_SECRET"),

      "facebook" => define(:facebook,
        authorize_url: "https://www.facebook.com/v21.0/dialog/oauth",
        token_url: "https://graph.facebook.com/v21.0/oauth/access_token",
        scopes: %w[pages_show_list pages_read_engagement pages_manage_posts
                   pages_manage_engagement read_insights business_management],
        client_id_env: "META_CLIENT_ID", client_secret_env: "META_CLIENT_SECRET"),

      "linkedin" => define(:linkedin,
        authorize_url: "https://www.linkedin.com/oauth/v2/authorization",
        token_url: "https://www.linkedin.com/oauth/v2/accessToken",
        scopes: %w[openid profile email w_member_social]),

      # Google's consent screen only returns a refresh token when it is asked
      # to, and only on the first grant -- hence access_type and prompt. Without
      # them the connection silently stops working an hour later.
      "youtube" => define(:youtube,
        authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
        token_url: "https://oauth2.googleapis.com/token",
        scopes: %w[https://www.googleapis.com/auth/youtube.upload
                   https://www.googleapis.com/auth/youtube.readonly
                   https://www.googleapis.com/auth/yt-analytics.readonly],
        authorize_params: { access_type: "offline", prompt: "consent", include_granted_scopes: "true" },
        client_id_env: "GOOGLE_CLIENT_ID", client_secret_env: "GOOGLE_CLIENT_SECRET"),

      "google_business" => define(:google_business,
        authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
        token_url: "https://oauth2.googleapis.com/token",
        scopes: %w[https://www.googleapis.com/auth/business.manage],
        authorize_params: { access_type: "offline", prompt: "consent" },
        client_id_env: "GOOGLE_CLIENT_ID", client_secret_env: "GOOGLE_CLIENT_SECRET"),

      "tiktok" => define(:tiktok,
        authorize_url: "https://www.tiktok.com/v2/auth/authorize/",
        token_url: "https://open.tiktokapis.com/v2/oauth/token/",
        scopes: %w[user.info.basic video.publish video.list],
        pkce: true,
        # TikTok names its client id "client_key" throughout, including in the
        # authorize query string. TokenExchange handles that rename.
        client_id_env: "TIKTOK_CLIENT_KEY", client_secret_env: "TIKTOK_CLIENT_SECRET"),

      "x" => define(:x,
        authorize_url: "https://x.com/i/oauth2/authorize",
        token_url: "https://api.x.com/2/oauth2/token",
        scopes: %w[tweet.read tweet.write users.read offline.access],
        pkce: true)
    }.freeze

    module_function

    def find(key) = ALL[key.to_s]
    def configured?(key) = find(key)&.configured? || false
    def configured_keys = ALL.keys.select { |k| configured?(k) }

    # Anything still carrying verified_on: nil. Surfaced by the connections
    # page so nobody ships a provider on values nobody has checked.
    def unverified = ALL.values.reject(&:verified?).map(&:key)

    # The redirect URI registered with each platform. It must match byte for
    # byte on both sides, must be https in production, and must be a single
    # fixed value -- which is why the workspace travels in the session rather
    # than in this path.
    def redirect_uri(provider, host: nil)
      host ||= ENV.fetch("APP_HOST", "localhost:3000")
      scheme = host.start_with?("localhost", "127.0.0.1") ? "http" : "https"
      "#{scheme}://#{host}/auth/#{provider}/callback"
    end
  end
end
