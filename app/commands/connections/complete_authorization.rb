module Connections
  # Finishes a real OAuth connection: verifies the round trip was ours, trades
  # the authorization code for tokens, asks the platform who the token belongs
  # to, and stores the result.
  #
  # The order matters. State is checked before the code is spent, because an
  # unsolicited code must never be exchanged. The profile is fetched before the
  # account row is written, because the row is keyed on the platform's own
  # account id and that id only arrives with the profile.
  class CompleteAuthorization < ApplicationCommand
    def initialize(workspace:, provider:, actor:, code:, state:, expected_state:, verifier: nil, host: nil)
      @workspace = workspace
      @provider = provider.to_s
      @actor = actor
      @code = code
      @state = state
      @expected_state = expected_state
      @verifier = verifier
      @host = host
    end

    def call
      return Result.failure(:unknown_provider) unless SocialProvider::Catalog.keys.include?(@provider)
      return Result.failure(:invalid_state) unless state_valid?
      return Result.failure(:no_code) if @code.blank?

      config = SocialProvider::OAuthConfig.find(@provider)
      return Result.failure(:not_configured) if config.nil? || !config.configured?

      credentials = SocialProvider::TokenExchange.exchange_code(
        config: config,
        code: @code,
        redirect_uri: SocialProvider::OAuthConfig.redirect_uri(@provider, host: @host),
        verifier: @verifier
      )

      adapter = SocialProvider::Registry.for(@provider, workspace: @workspace, credentials: credentials)
      profile = adapter.fetch_profile

      ConnectAccount.call(
        workspace: @workspace, provider: @provider, actor: @actor,
        profile: profile, credentials: credentials
      )
    rescue SocialProvider::PermanentError, SocialProvider::TransientError => e
      Result.failure(e)
    end

    private

    # Constant-time, and length-checked first because secure_compare raises on
    # a length mismatch. Blank state is rejected outright rather than compared,
    # so a missing value can never coincidentally match another missing value.
    def state_valid?
      return false if @state.blank? || @expected_state.blank?
      return false unless @state.bytesize == @expected_state.bytesize

      ActiveSupport::SecurityUtils.secure_compare(@state, @expected_state)
    end
  end
end
