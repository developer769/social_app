class Post < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[draft awaiting_approval approved scheduled publishing published failed cancelled].freeze

  # How each status reads on the calendar, and the tone it carries. Kept here so
  # every screen describes a post the same way.
  STATUS_LABELS = {
    "draft" => [ "Draft", :neutral ],
    "awaiting_approval" => [ "Awaiting approval", :warning ],
    "approved" => [ "Approved", :info ],
    "scheduled" => [ "Scheduled", :info ],
    "publishing" => [ "Publishing", :warning ],
    "published" => [ "Published", :success ],
    "failed" => [ "Failed", :danger ],
    "cancelled" => [ "Cancelled", :neutral ]
  }.freeze

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :template, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :post_media, -> { order(:position) }, dependent: :destroy, inverse_of: :post
  has_many :media_assets, through: :post_media
  has_many :post_targets, dependent: :destroy
  # Nullified rather than destroyed: a generation is a record of what was made
  # and what it cost, and it outlives the draft it was made for.
  has_many :creative_requests, dependent: :nullify

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :scheduled_between, ->(from, to) { where(scheduled_at: from..to) }
  scope :upcoming, -> { where(status: %w[scheduled approved awaiting_approval]).where(scheduled_at: Time.current..) }
  scope :chronological, -> { order(:scheduled_at, :id) }
  scope :for_provider, ->(provider) { joins(:post_targets).where(post_targets: { provider: provider }).distinct }

  validates :caption, length: { maximum: 5_000 }, allow_blank: true
  validates :hashtags, length: { maximum: 30 }

  def status_label = STATUS_LABELS.fetch(status).first
  def status_tone = STATUS_LABELS.fetch(status).last

  def providers = post_targets.map(&:provider).uniq

  def primary_media = post_media.first&.media_asset

  # The time as the workspace saw it when scheduling, not as it is read today:
  # changing the workspace timezone must not silently move an existing post.
  def scheduled_at_local
    return if scheduled_at.blank?

    scheduled_at.in_time_zone(scheduled_timezone.presence || workspace.timezone)
  end

  def scheduled_date_local = scheduled_at_local&.to_date

  # ---- Transitions --------------------------------------------------------
  # Explicit methods rather than assigning to status from a controller, so
  # every change has one auditable entry point (spec 10).

  def schedule_for!(time, timezone: nil)
    zone = timezone.presence || workspace.timezone
    update!(status: "scheduled", scheduled_at: time, scheduled_timezone: zone)
  end

  def return_to_draft!
    update!(status: "draft")
  end

  def cancel!
    update!(status: "cancelled")
  end

  def start_publishing!
    update!(status: "publishing")
  end

  # The parent's status is DERIVED from its targets rather than set
  # independently, because a post to three platforms can succeed twice and fail
  # once, and one column cannot describe that on its own.
  def settle_from_targets!
    targets = post_targets.reload
    return if targets.empty? || targets.any? { |target| !target.finished? }

    published = targets.count(&:published?)

    update!(
      status: published.zero? ? "failed" : "published",
      published_at: published.positive? ? (targets.filter_map(&:published_at).min || Time.current) : nil
    )
  end

  def partially_published?
    published? && post_targets.any?(&:failed?)
  end
end
