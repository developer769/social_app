module Analysis
  # Depends on published performance history from a real connected account.
  # Until one exists it says so plainly instead of returning invented figures
  # (spec 22: do not invent performance claims; spec 27: never present demo
  # data as real connected-account data).
  class AudienceEngagement < Analyzer
    def call
      if connected_accounts.empty?
        return Outcome.needs_connection(reason: "Connect a social account and Prachar can measure likes, comments and shares.")
      end

      unless real_performance_data?
        return Outcome.needs_connection(
          reason: "Your connected accounts are simulated, so there is no real performance history to read yet."
        )
      end

      Outcome.insufficient_data(reason: "Not enough engagement recorded yet to draw a conclusion.")
    end
  end
end
