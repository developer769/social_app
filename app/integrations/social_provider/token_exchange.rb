require "securerandom"
require "digest"
require "base64"

module SocialProvider
  # The two halves of OAuth 2.0 that are identical everywhere: turning an
  # authorization code into tokens, and turning a refresh token into a fresh
  # access token.
  #
  # Written once, generically, because this part genuinely does not vary
  # between platforms -- only endpoints and scopes do, and those live in
  # OAuthConfig. Provider-specific work (reading a profile, publishing) belongs
  # in that provider's adapter, not here.
  module TokenExchange
    module_function

    # PKCE (RFC 7636). Required by X and TikTok, harmless and beneficial
    # everywhere else, so it is generated for every provider that asks for it
    # and simply not sent by the ones that do not.
    def generate_verifier = SecureRandom.urlsafe_base64(64).tr("=", "")

    def challenge_for(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end

    # The URL we send somebody to on the platform's own domain. Nothing secret
    # goes in it: the client secret never leaves this server.
    def authorization_url(config:, state:, redirect_uri:, verifier: nil)
      params = {
        response_type: "code",
        redirect_uri: redirect_uri,
        state: state,
        scope: config.scope_string
      }.merge(config.authorize_params)

      params[client_id_param(config)] = config.client_id

      if config.pkce? && verifier.present?
        params[:code_challenge] = challenge_for(verifier)
        params[:code_challenge_method] = "S256"
      end

      uri = URI(config.authorize_url)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def exchange_code(config:, code:, redirect_uri:, verifier: nil)
      form = {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_secret: config.client_secret
      }
      form[client_id_param(config)] = config.client_id
      form[:code_verifier] = verifier if config.pkce? && verifier.present?

      credentials_from(post_token(config, form), fallback_refresh: nil)
    end

    def refresh(config:, refresh_token:)
      form = {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_secret: config.client_secret
      }
      form[client_id_param(config)] = config.client_id

      # Providers that rotate refresh tokens return a new one; the ones that do
      # not return nothing, and the old token must be kept. Dropping it here
      # would silently un-connect the account at the next refresh.
      credentials_from(post_token(config, form), fallback_refresh: refresh_token)
    end

    # TikTok calls it client_key everywhere. Everyone else follows the RFC.
    def client_id_param(config) = config.key == "tiktok" ? :client_key : :client_id

    def post_token(config, form)
      headers = {}
      # X requires HTTP Basic client authentication on the token endpoint for
      # confidential clients; sending the secret in the body is rejected.
      if config.key == "x"
        form.delete(:client_secret)
        basic = Base64.strict_encode64("#{config.client_id}:#{config.client_secret}")
        headers["authorization"] = "Basic #{basic}"
      end

      HttpClient.new(provider: config.key).post_form(config.token_url, form: form, headers: headers)
    end

    def credentials_from(body, fallback_refresh:)
      # TikTok nests the payload one level down under "data" on some versions
      # of its token endpoint; unwrap before looking for the token.
      payload = body.is_a?(Hash) && body["data"].is_a?(Hash) && body["data"]["access_token"] ? body["data"] : body

      access = payload["access_token"]
      if access.blank?
        raise PermanentError.new(
          "The platform did not return an access token.", code: "no_access_token"
        )
      end

      expires_in = payload["expires_in"] || payload["expires_in_seconds"]

      CredentialsDto.new(
        access_token: access,
        refresh_token: payload["refresh_token"].presence || fallback_refresh,
        # A token with no stated lifetime is treated as long-lived rather than
        # as already expired; the account's own expiry check is what stops
        # publishing, and guessing "now" would break a working connection.
        expires_at: expires_in.present? ? expires_in.to_i.seconds.from_now : nil
      )
    end
  end
end
