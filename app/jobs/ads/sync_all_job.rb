module Ads
  # Sweeps every campaign that could still have figures to report.
  #
  # Finished campaigns are included for a while after they end, because late
  # conversions land days later and a campaign closed on Tuesday can still gain
  # a sale on Friday.
  class SyncAllJob < ApplicationJob
    queue_as :default

    TAIL = 14.days

    def perform
      AdCampaign.where.not(status: "draft")
                .where("ends_on IS NULL OR ends_on >= ?", Date.current - TAIL)
                .find_each { |campaign| SyncMetricsJob.perform_later(campaign.id) }
    end
  end
end
