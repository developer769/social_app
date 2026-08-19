class Plan < ApplicationRecord
  INTERVALS = %w[month year].freeze

  # The entitlement keys the application asks about. Nothing branches on a plan
  # name; everything asks for one of these (spec 22).
  ENTITLEMENT_KEYS = %w[
    social_accounts
    posts_per_month
    team_members
    ai_generations_per_month
    analytics_history_days
    support_level
  ].freeze

  has_many :plan_entitlements, dependent: :destroy
  has_many :subscriptions, dependent: :restrict_with_error

  enum :interval, INTERVALS.index_by(&:itself), prefix: :billed, validate: true

  scope :active, -> { where(active: true) }
  scope :in_display_order, -> { order(:position, :id) }
  scope :billed_monthly, -> { where(interval: "month") }
  scope :for_interval, ->(interval) { where(interval: interval) }

  validates :code, presence: true, uniqueness: { scope: :interval }
  validates :name, presence: true
  validates :price_minor, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :currency, presence: true, length: { is: 3 }

  def price = Money.new(minor_units: price_minor, currency: currency)

  def entitlement(key) = plan_entitlements.find { |e| e.key == key.to_s }

  # nil limit means unlimited, which must not be confused with zero.
  def limit_for(key) = entitlement(key)&.limit_value

  def unlimited?(key)
    entitlement = entitlement(key)
    entitlement.present? && entitlement.limit_value.nil?
  end

  def features = plan_entitlements.sort_by(&:id).map(&:display_label)
end
