module SocialHealth
  # One signal in the score.
  #
  # A component is either measured, in which case it carries a 0-100 value, or
  # unavailable, in which case it carries the reason and contributes nothing.
  # An unavailable component is never scored as zero: "we could not measure
  # this" and "this is bad" are different statements, and conflating them would
  # invent a performance claim (spec 22, 27).
  class Component
    attr_reader :key, :label, :weight, :value, :reason, :detail, :findings

    def self.measured(key:, label:, weight:, value:, detail: nil, findings: [])
      new(key: key, label: label, weight: weight, value: value.clamp(0, 100),
          detail: detail, findings: findings, measured: true)
    end

    def self.unavailable(key:, label:, weight:, reason:)
      new(key: key, label: label, weight: weight, reason: reason, measured: false)
    end

    def initialize(key:, label:, weight:, measured:, value: nil, reason: nil, detail: nil, findings: [])
      @key = key
      @label = label
      @weight = weight
      @value = value
      @reason = reason
      @detail = detail
      @findings = findings.freeze
      @measured = measured
      freeze
    end

    def measured? = @measured

    def to_h
      {
        key: key, label: label, weight: weight, measured: measured?,
        value: value, reason: reason, detail: detail, findings: findings
      }
    end
  end
end
