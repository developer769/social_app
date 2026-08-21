module CreativeProvider
  # Retrying will never help, and generation costs money per call, so a
  # permanent failure must never be retried: a content refusal, an unusable
  # brief, an ineligible account.
  class PermanentError < Error
    attr_reader :code

    def initialize(message = nil, code: nil)
      @code = code
      super(message)
    end
  end
end
