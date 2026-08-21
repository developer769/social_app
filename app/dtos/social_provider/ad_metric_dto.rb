module SocialProvider
  # One day of one campaign as a platform reported it.
  #
  # Every figure defaults to nil rather than zero. A platform that does not
  # report reach, or a business with no pixel telling it about purchases, must
  # leave those fields empty -- a zero here would travel all the way to a
  # shop owner's screen as "nobody saw it" or "nothing sold".
  class AdMetricDto < ApplicationDto
    attribute :on_date, :spend_minor, :currency, :impressions, :reach, :clicks,
              :results, :result_kind, :conversions, :conversion_value_minor

    def initialize(on_date:, currency:, spend_minor: nil, impressions: nil, reach: nil,
                   clicks: nil, results: nil, result_kind: nil, conversions: nil,
                   conversion_value_minor: nil)
      @on_date = on_date.to_date
      @currency = currency.to_s.upcase
      @spend_minor = spend_minor
      @impressions = impressions
      @reach = reach
      @clicks = clicks
      @results = results
      @result_kind = result_kind
      @conversions = conversions
      @conversion_value_minor = conversion_value_minor
      freeze
    end

    def to_attributes
      {
        on_date: on_date, currency: currency, spend_minor: spend_minor,
        impressions: impressions, reach: reach, clicks: clicks,
        results: results, result_kind: result_kind,
        conversions: conversions, conversion_value_minor: conversion_value_minor
      }
    end
  end
end
