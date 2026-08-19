module SocialProvider
  # Retrying with backoff and jitter is appropriate: rate limits, timeouts, 5xx.
  class TransientError < Error
    attr_reader :code, :retry_after

    def initialize(message = nil, code: nil, retry_after: nil)
      @code = code
      @retry_after = retry_after
      super(message)
    end
  end
end
