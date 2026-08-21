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

  private

  def budget_is_present
    return if daily_budget_minor.present? || total_budget_minor.present?

    errors.add(:base, "Set a daily budget or a total budget")
  end
end
