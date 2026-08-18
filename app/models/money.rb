# A minimal money value object. Amounts are integer minor units plus an explicit
# currency, so nothing is ever a float and INR is never assumed.
class Money
  include Comparable

  # Currencies whose minor unit is not 1/100.
  EXPONENTS = { "JPY" => 0, "KRW" => 0, "KWD" => 3, "BHD" => 3 }.freeze
  SYMBOLS = { "INR" => "\u20B9", "USD" => "$", "EUR" => "\u20AC", "GBP" => "\u00A3", "JPY" => "\u00A5" }.freeze

  attr_reader :minor_units, :currency

  def initialize(minor_units:, currency:)
    @minor_units = Integer(minor_units)
    @currency = currency.to_s.upcase
    freeze
  end

  def self.from_major(amount, currency:)
    return if amount.blank?

    exponent = EXPONENTS.fetch(currency.to_s.upcase, 2)
    new(minor_units: (BigDecimal(amount.to_s) * (10**exponent)).round, currency: currency)
  end

  def exponent = EXPONENTS.fetch(currency, 2)
  def major = BigDecimal(minor_units) / (10**exponent)
  def symbol = SYMBOLS.fetch(currency, "#{currency} ")
  def zero? = minor_units.zero?

  def <=>(other)
    raise ArgumentError, "cannot compare #{currency} with #{other.currency}" unless currency == other.currency

    minor_units <=> other.minor_units
  end

  def ==(other)
    other.is_a?(Money) && other.minor_units == minor_units && other.currency == currency
  end
end
