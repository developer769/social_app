module Connections
  # Begins a real OAuth connection: builds the URL on the platform's own domain
  # that the owner is about to be sent to, plus the two secrets that have to
  # survive the round trip.
  #
  # `state` is CSRF protection for the callback. Without it, anybody could hand
  # a signed-in owner a crafted callback URL and attach an attacker's social
  # account to that workspace. It is compared on the way back, once, and
  # discarded.
  #
  # `verifier` is the PKCE secret. It never leaves this server -- only its
  # SHA-256 hash goes to the platform -- so an intercepted authorization code
  # is useless without it.
  class StartAuthorization < ApplicationCommand
    Authorization = Struct.new(:url, :state, :verifier, :provider, keyword_init: true)

    # Ten minutes is longer than any honest consent screen takes and short
    # enough that an abandoned attempt cannot be resumed later.
    TTL = 10.minutes

    def initialize(workspace:, provider:, host: nil)
      @workspace = workspace
      @provider = provider.to_s
      @host = host
    end

    def call
      return Result.failure(:unknown_provider) unless SocialProvider::Catalog.keys.include?(@provider)

      config = SocialProvider::OAuthConfig.find(@provider)
      return Result.failure(:not_configured) if config.nil? || !config.configured?

      state = SecureRandom.urlsafe_base64(32)
      verifier = config.pkce? ? SocialProvider::TokenExchange.generate_verifier : nil

      url = SocialProvider::TokenExchange.authorization_url(
        config: config,
        state: state,
        redirect_uri: SocialProvider::OAuthConfig.redirect_uri(@provider, host: @host),
        verifier: verifier
      )

      Result.success(Authorization.new(url: url, state: state, verifier: verifier, provider: @provider))
    end
  end
end
