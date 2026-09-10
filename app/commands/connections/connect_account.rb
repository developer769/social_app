module Connections
  # Connects (or reconnects) one provider account to a workspace.
  #
  # Idempotent on the provider's own account id: reconnecting the same account
  # updates the existing row rather than creating a duplicate, which matters
  # because reconnection after token expiry is a routine event, not an error.
  class ConnectAccount < ApplicationCommand
    # profile/credentials arrive already fetched when a real OAuth round trip
    # produced them (CompleteAuthorization holds the PKCE verifier, so the
    # exchange has to happen there). Without them this falls back to asking the
    # adapter directly, which is the mock path.
    def initialize(workspace:, provider:, actor:, authorization_code: nil, profile: nil, credentials: nil)
      @workspace = workspace
      @provider = provider.to_s
      @actor = actor
      @authorization_code = authorization_code
      @profile = profile
      @credentials = credentials
    end

    def call
      return Result.failure(:unknown_provider) unless SocialProvider::Catalog.keys.include?(@provider)

      if @profile && @credentials
        profile = @profile
        credentials = @credentials
      else
        adapter = SocialProvider::Registry.for(@provider, workspace: @workspace)
        profile = adapter.connect(authorization_code: @authorization_code)
        credentials = adapter.refresh_authorization
      end

      account = nil

      ActiveRecord::Base.transaction do
        account = @workspace.social_accounts.find_or_initialize_by(
          provider: @provider, external_account_id: profile.external_account_id
        )
        account.save!
        account.mark_connected!(profile: profile, connected_by: @actor)
        store_credentials(account, credentials)

        AuditEvent.record!(
          action: "social_account.connected",
          workspace: @workspace,
          actor_user: @actor,
          auditable: account,
          # The provider and handle are safe to record; the token is not.
          metadata: { provider: @provider, handle: account.handle, mocked: account.mocked? }
        )
      end

      Result.success(account)
    rescue SocialProvider::PermanentError => e
      Result.failure(e)
    rescue SocialProvider::TransientError => e
      Result.failure(e)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def store_credentials(account, credentials)
      record = account.social_credential || account.build_social_credential
      record.update!(
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        expires_at: credentials.expires_at
      )
    end
  end
end
