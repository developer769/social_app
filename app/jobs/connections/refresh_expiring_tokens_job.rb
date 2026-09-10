module Connections
  # Refreshes access tokens before they die.
  #
  # Refreshing on failure is too late: the first thing to notice an expired
  # token would be a customer's scheduled post, and a post that missed its slot
  # cannot be un-missed. So this sweeps ahead of expiry instead.
  #
  # Mocked providers are skipped -- there is nothing to refresh and the mock
  # would happily hand back another fake token, hiding the fact that no real
  # connection exists.
  class RefreshExpiringTokensJob < ApplicationJob
    queue_as :default

    # Wide enough that a daily sweep gets several attempts before anything
    # actually expires.
    HORIZON = 3.days

    def perform
      accounts.find_each do |account|
        refresh(account)
      rescue StandardError => e
        # One provider being down must not stop the rest of the sweep.
        Rails.logger.error(
          message: "token refresh failed",
          social_account_id: account.id, provider: account.provider, error: e.class.name
        )
      end
    end

    private

    def accounts
      SocialAccount
        .connected
        .where.not(token_expires_at: nil)
        .where(token_expires_at: ..HORIZON.from_now)
    end

    def refresh(account)
      return if SocialProvider::Registry.mocked?(account.provider)

      credentials = SocialProvider::Registry.for(
        account.provider, workspace: account.workspace, account: account
      ).refresh_authorization

      credential = account.social_credential || account.build_social_credential
      credential.update!(
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token.presence || credential.refresh_token,
        expires_at: credentials.expires_at
      )
      account.update!(token_expires_at: credentials.expires_at)

      Rails.logger.info(
        message: "token refreshed", social_account_id: account.id, provider: account.provider
      )
    rescue SocialProvider::PermanentError => e
      # The connection is genuinely dead: the owner has to grant access again.
      # Marking it expired is what stops the publisher from trying and what
      # surfaces the "reconnect" prompt in Settings.
      account.mark_expired!
      Rails.logger.warn(
        message: "token refresh permanently failed",
        social_account_id: account.id, provider: account.provider, code: e.code
      )
    end
  end
end
