# Money put behind one post on one platform.
class AdCampaign < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[draft pending running paused finished failed].freeze
  OBJECTIVES = {
    "reach" => "Be seen by more people",
    "engagement" => "Get more likes and comments",
    "traffic" => "Send people to a link",
    "messages" => "Start conversations",
    "leads" => "Collect enquiries"
  }.freeze

  STATUS_LABELS = {
    "draft" => [ "Draft", :neutral ],
    "pending" => [ "Waiting for review", :warning ],
    "running" => [ "Running", :success ],
    "paused" => [ "Paused", :neutral ],
    "finished" => [ "Finished", :info ],
    "failed" => [ "Did not start", :danger ]
  }.freeze

  belongs_to :post
  belongs_to :social_account
  belongs_to :created_by, class_name: "User", optional: true

  has_many :ad_metrics, -> { order(:on_date) }, dependent: :destroy, inverse_of: :ad_campaign
  has_many :ad_outcomes, -> { newest_first }, dependent: :destroy, inverse_of: :ad_campaign

  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :objective, OBJECTIVES.keys.index_by(&:itself), prefix: :for, validate: true

  validates :name, presence: true, length: { maximum: 120 }
  validates :provider, inclusion: { in: SocialProvider::Catalog::KEYS }
  validate :budget_is_present

  scope :live, -> { where(status: %w[pending running paused]) }
  scope :recent_first, -> { order(created_at: :desc) }

  def status_label = STATUS_LABELS.fetch(status).first
  def status_tone = STATUS_LABELS.fetch(status).last
  def objective_label = OBJECTIVES.fetch(objective)
  def provider_name = social_account&.provider_name || provider.humanize

  def daily_budget = daily_budget_minor && Money.new(minor_units: daily_budget_minor, currency: currency)
  def total_budget = total_budget_minor && Money.new(minor_units: total_budget_minor, currency: currency)

  # Summed from the days the platform actually reported, so a campaign whose
  # figures have not arrived reads as unknown rather than as zero spend.
  def spend
    reported = ad_metrics.filter_map(&:spend_minor)
    return if reported.empty?

    Money.new(minor_units: reported.sum, currency: currency)
  end

  def measured? = ad_metrics.any?

  # Nil, never zero, when the platform does not report the figure at all.
  def total_for(field)
    values = ad_metrics.filter_map { |metric| metric.public_send(field) }
    values.empty? ? nil : values.sum
  end

  # ---- Revenue -------------------------------------------------------------
  # Two sources, never added together. What a platform measured and what the
  # owner counted are different kinds of claim, and a single blended figure
  # would be worth less than either of them on its own.

  # Only ever what a pixel or conversions API reported. Nil is the normal case.
  def measured_revenue
    values = ad_metrics.filter_map(&:conversion_value_minor)
    return if values.empty?

    Money.new(minor_units: values.sum, currency: currency)
  end

  def recorded_revenue
    values = ad_outcomes.filter_map(&:revenue_minor)
    return if values.empty?

    Money.new(minor_units: values.sum, currency: currency)
  end

  def recorded_orders
    counts = ad_outcomes.filter_map(&:orders)
    counts.empty? ? nil : counts.sum
  end

  # Return on ad spend, as a multiple. Computed only when BOTH halves are
  # genuinely known: an unknown treated as zero would put a confident number
  # about money in front of somebody deciding whether to spend more.
  #
  # source is :measured or :recorded, and callers must carry it through to the
  # screen. A ROAS whose provenance is not stated is worse than none.
  def return_on_spend(source: :recorded)
    revenue = source == :measured ? measured_revenue : recorded_revenue
    spent = spend
    return if revenue.nil? || spent.nil? || spent.minor_units.zero?

    (revenue.minor_units.to_f / spent.minor_units).round(2)
  end

  def cost_per_order
    orders = recorded_orders
    spent = spend
    return if orders.nil? || orders.zero? || spent.nil?

    Money.new(minor_units: (spent.minor_units.to_f / orders).round, currency: currency)
  end

  private

  def budget_is_present
    return if daily_budget_minor.present? || total_budget_minor.present?

    errors.add(:base, "Set a daily budget or a total budget")
  end
end
