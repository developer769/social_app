# Formats Money for display.
#
# India groups digits as 2,2,3 rather than 3,3,3 (12,34,567 not 1,234,567) and
# abbreviates in lakh and crore rather than millions. The Ads screen in the
# designs shows both forms: a spend of "\u20B942.6K" beside a revenue of
# "\u20B91.46L". Rails' number_to_currency does neither, so this does.
class MoneyPresenter
  INDIAN_CURRENCIES = %w[INR].freeze

  def initialize(money)
    @money = money
  end

  # \u20B91,549  /  \u20B912,34,567  /  $1,234.50
  def full(precision: nil)
    return "" if @money.nil?

    precision = precision.nil? ? (@money.major.frac.zero? ? 0 : @money.exponent) : precision
    amount = @money.major.round(precision)
    "#{@money.symbol}#{group(format("%.#{precision}f", amount))}"
  end

  # \u20B942.6K  /  \u20B91.46L  /  \u20B92.3Cr  /  $1.2M
  def compact
    return "" if @money.nil?

    value = @money.major.abs
    sign = @money.minor_units.negative? ? "-" : ""

    unit, divisor = compact_unit(value)
    return "#{sign}#{@money.symbol}#{group(format('%.0f', @money.major.abs))}" if divisor == 1

    scaled = (value / divisor).round(scaled_precision(value / divisor))
    "#{sign}#{@money.symbol}#{trim(scaled)}#{unit}"
  end

  private

  def indian? = INDIAN_CURRENCIES.include?(@money.currency)

  def compact_unit(value)
    if indian?
      return [ "Cr", 10_000_000 ] if value >= 10_000_000
      return [ "L", 100_000 ] if value >= 100_000
      return [ "K", 1_000 ] if value >= 1_000
    else
      return [ "B", 1_000_000_000 ] if value >= 1_000_000_000
      return [ "M", 1_000_000 ] if value >= 1_000_000
      return [ "K", 1_000 ] if value >= 1_000
    end

    [ "", 1 ]
  end

  # Two significant decimals under 10, one above, so 1.46L and 42.6K both read
  # the way the designs show them.
  def scaled_precision(scaled) = scaled < 10 ? 2 : 1

  def trim(number)
    formatted = number.to_s("F")
    formatted.sub(/\.?0+\z/, "")
  end

  # Indian grouping is 2,2,3 from the right; Western is 3,3,3.
  def group(number_string)
    whole, decimals = number_string.split(".")
    negative = whole.start_with?("-")
    whole = whole.delete_prefix("-")

    grouped =
      if indian? && whole.length > 3
        head = whole[0..-4]
        "#{head.reverse.scan(/\d{1,2}/).join(',').reverse},#{whole[-3..]}"
      else
        whole.reverse.scan(/\d{1,3}/).join(",").reverse
      end

    [ negative ? "-#{grouped}" : grouped, decimals ].compact.join(".")
  end
end
