module Ads
  # Writes a platform's daily figures into our own tables.
  #
  # Upserts on the day, so re-fetching corrects a figure rather than adding a
  # second copy of it. Platforms revise recent days for days afterwards, which
  # is exactly why the window overlaps and why this must be idempotent.
  class ImportMetrics < ApplicationCommand
    def initialize(campaign:, rows:)
      @campaign = campaign
      @rows = Array(rows)
    end

    def call
      written = 0

      ActiveRecord::Base.transaction do
        @rows.each do |dto|
          metric = @campaign.ad_metrics.find_or_initialize_by(on_date: dto.on_date)
          metric.assign_attributes(dto.to_attributes.merge(fetched_at: Time.current))
          metric.save!
          written += 1
        end

        @campaign.update!(last_synced_at: Time.current)
      end

      Result.success(written)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
