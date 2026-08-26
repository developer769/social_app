module Sessions
  # Deletes sessions that can no longer be used.
  #
  # Nothing removed them before, so the row for every sign-in a person ever
  # made lived for ever and all of them were listed on the security page. A
  # development workspace reached 67 in eight days; somebody signing in daily
  # on three devices reaches a thousand in a year, and a list of a thousand
  # devices tells them nothing about any of them.
  #
  # Safe to delete rather than hide: revoking and expiring are already recorded
  # as audit events, which is where the history belongs. The session row is
  # only a credential, and a spent credential is not history.
  class SweepJob < ApplicationJob
    queue_as :default

    # Kept a little past the point of no use, so "you were signed out an hour
    # ago" is still answerable from the row itself if anyone asks.
    RETENTION = 30.days

    def perform
      cutoff = RETENTION.ago

      revoked = Session.where.not(revoked_at: nil).where(revoked_at: ..cutoff).delete_all
      expired = Session.where(expires_at: ..cutoff).delete_all

      Rails.logger.info(message: "swept spent sessions", revoked: revoked, expired: expired)
    end
  end
end
