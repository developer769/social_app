module Analysis
  # What an analyzer produces. The outcome is as important as the result: a task
  # that found nothing must say so, rather than returning zeros that would read
  # as a measurement (spec 27).
  class Outcome
    attr_reader :outcome, :result

    def self.analysed(result) = new(outcome: "analysed", result: result)
    def self.insufficient_data(reason:) = new(outcome: "insufficient_data", result: { reason: reason })
    def self.needs_connection(reason:) = new(outcome: "not_supported", result: { reason: reason })

    def initialize(outcome:, result: {})
      @outcome = outcome
      @result = result
      freeze
    end
  end
end
