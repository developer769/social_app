module SocialProvider
  # Retrying will never help: a revoked permission, an ineligible account,
  # media the platform rejects. Retrying these burns quota and can get an app
  # flagged, so the job must not reschedule (spec 30).
  class PermanentError < Error
    attr_reader :code

    def initialize(message = nil, code: nil)
      @code = code
      super(message)
    end
  end
end
