module Templates
  # Runs the catalogue refresh. Scheduled hourly in production; safe to run at
  # any time because the command is idempotent -- it recomputes scores from
  # current evidence rather than accumulating.
  class RefreshCatalogJob < ApplicationJob
    queue_as :default

    def perform
      result = RefreshCatalog.call

      return if result.success?

      Rails.logger.error(
        message: "template catalogue refresh failed",
        refresh_id: result.error&.id,
        error: result.error&.error_message
      )
    end
  end
end
