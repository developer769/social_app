# One day of one campaign, as the platform reported it.
#
# Every figure is nullable on purpose. Platforms report different things, and a
# metric a platform does not provide stays NULL rather than becoming a zero
# that reads as "none happened".
class AdMetric < ApplicationRecord
  FIELDS = %i[spend_minor impressions reach clicks results].freeze

  belongs_to :ad_campaign

  validates :on_date, presence: true, uniqueness: { scope: :ad_campaign_id }

  scope :between, ->(from, to) { where(on_date: from..to) }

  def spend = spend_minor && Money.new(minor_units: spend_minor, currency: currency)

  # Cost per result, computed only when both halves were measured. Dividing by
  # a zero we assumed would produce a confident number about money.
  def cost_per_result
    return if spend_minor.blank? || results.blank? || results.zero?

    Money.new(minor_units: (spend_minor.to_f / results).round, currency: currency)
  end
end
