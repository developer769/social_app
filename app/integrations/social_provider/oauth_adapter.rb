module SocialProvider
  # Base for every real adapter.
  #
  # It supplies the parts that are the same for all of them -- token refresh,
  # an authenticated HTTP client, expiry handling -- so a provider's own class
  # only has to answer the questions that are genuinely about that provider:
  # what its profile looks like, how it publishes, where its figures live.
  #
  # To add a provider:
  #
  #   1. class Instagram::Adapter < SocialProvider::OAuthAdapter
  #   2. implement fetch_profile, publish, fetch_analytics, fetch_conversations
  #   3. register it:  REAL_ADAPTERS = { "instagram" => Instagram::Adapter }
  #
  # Nothing else in the application changes. Registry falls back to MockAdapter
  # for every key that is not registered, so providers can go live one at a
  # time without a flag day.
  class OAuthAdapter < Adapter
    # `credentials` exists for the moment between exchanging an authorization
    # code and having an account row to attach it to: the profile has to be
    # fetched with the new token to learn the external account id that the row
    # is keyed on, so for that one call the token cannot come from the record.
    def initialize(account: nil, credentials: nil)
      if account.nil? && credentials.nil?
        raise ArgumentError, "OAuthAdapter needs an account or credentials"
      end

      @credentials = credentials
      super(account: account)
    end

    def config = OAuthConfig.find(key)

    # The authorization code has already been exchanged by the time an adapter
    # is built -- CompleteAuthorization does that, because it holds the PKCE
    # verifier from the session. So connecting is only ever "tell me who this
    # token belongs to".
    def connect(authorization_code: nil) = fetch_profile

    def refresh_authorization
      token = @credentials&.refresh_token || credential&.refresh_token
      if token.blank?
        raise PermanentError.new(
          "#{definition&.name || key} did not provide a refresh token, so this connection "         "has to be made again by hand.",
          code: "no_refresh_token"
        )
      end

      TokenExchange.refresh(config: config, refresh_token: token)
    end

    private

    def credential = account&.social_credential

    def access_token
      token = @credentials&.access_token || credential&.access_token
      raise PermanentError.new("This account has no stored token.", code: "no_token") if token.blank?

      token
    end

    # Authenticated calls go through here so no subclass has to remember the
    # header, and so a 401 is translated once into the thing the rest of the
    # app understands: this connection needs re-authorising.
    def http = @http ||= HttpClient.new(provider: key)

    def authorized_get(url, params: {})
      http.get(url, params: params, headers: bearer)
    rescue PermanentError => e
      raise reauthorization_needed(e)
    end

    def authorized_post(url, body:)
      http.post_json(url, body: body, headers: bearer)
    rescue PermanentError => e
      raise reauthorization_needed(e)
    end

    def bearer = { "authorization" => "Bearer #{access_token}" }

    def reauthorization_needed(error)
      return error unless %w[401 403].include?(error.code.to_s)

      # No account yet means this is the profile fetch during connection: there
      # is nothing to mark, and the message below is still the right one.
      account&.mark_expired!
      PermanentError.new(
        "#{definition&.name || key} no longer accepts this connection. Reconnect the account "       "in Settings to publish again.",
        code: "reauthorization_required"
      )
    end
  end
end
