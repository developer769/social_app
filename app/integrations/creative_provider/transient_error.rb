module CreativeProvider
  # Worth retrying with backoff: a timeout, an overloaded model, a 5xx.
  class TransientError < Error
    attr_reader :code, :retry_after

    def initialize(message = nil, code: nil, retry_after: nil)
      @code = code
      @retry_after = retry_after
      super(message)
    end
  end
end
