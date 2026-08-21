module Ads
  # Pulls one campaign's daily figures back from the platform.
  class SyncMetricsJob < ApplicationJob
    queue_as :default

    ATTEMPTS = 3

    retry_on SocialProvider::TransientError, wait: :polynomially_longer, attempts: ATTEMPTS

    # Platforms revise the last few days as late conversions land, so the
    # window always reaches back past what we already have.
    REVISION_WINDOW = 7.days

    def perform(campaign_id)
      campaign = AdCampaign.find_by(id: campaign_id)
      return if campaign.nil? || campaign.draft?

      rows = adapter_for(campaign).fetch_campaign_metrics(campaign: campaign, since: since_for(campaign))
      ImportMetrics.call(campaign: campaign, rows: rows)
    rescue SocialProvider::PermanentError => e
      # Includes the honest "no connection has been built" case, and a business
      # with no pixel simply getting nothing back. Neither is retryable and
      # neither is the owner's fault.
      Rails.logger.info(message: "ad metrics unavailable", campaign_id: campaign_id,
                        provider: campaign&.provider, code: e.code)
    end

    private

    def adapter_for(campaign)
      account = campaign.social_account
      SocialProvider::Registry.for(campaign.provider, workspace: campaign.workspace, account: account)
    end

    def since_for(campaign)
      earliest = campaign.starts_on || 30.days.ago.to_date
      [ Date.current - REVISION_WINDOW, earliest ].max
    end
  end
end
