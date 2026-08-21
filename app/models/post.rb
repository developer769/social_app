class Post < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[draft awaiting_approval approved scheduled publishing published
                partially_published reminded failed cancelled].freeze

  PUBLISH_MODES = %w[automatic reminder].freeze

  # How each status reads on the calendar, and the tone it carries. Kept here so
  # every screen describes a post the same way.
  STATUS_LABELS = {
    "draft" => [ "Draft", :neutral ],
    "awaiting_approval" => [ "Awaiting approval", :warning ],
    "approved" => [ "Approved", :info ],
    "scheduled" => [ "Scheduled", :info ],
    "publishing" => [ "Publishing", :warning ],
    "published" => [ "Published", :success ],
    "partially_published" => [ "Partly published", :warning ],
    "reminded" => [ "Reminder sent", :info ],
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
  enum :publish_mode, PUBLISH_MODES.index_by(&:itself), prefix: :publish, validate: true

  scope :scheduled_between, ->(from, to) { where(scheduled_at: from..to) }
  scope :upcoming, -> { where(status: %w[scheduled approved awaiting_approval]).where(scheduled_at: Time.current..) }
  # Everything whose moment has arrived. Deliberately unbounded at the far end:
  # a worker outage must not cause posts to be skipped for ever, only to go out
  # late, and going out late is the owner's call to make (see Dispatch).
  scope :due_for_publishing, ->(now = Time.current) { where(status: "scheduled").where(scheduled_at: ..now) }
  scope :chronological, -> { order(:scheduled_at, :id) }
  scope :for_provider, ->(provider) { joins(:post_targets).where(post_targets: { provider: provider }).distinct }

  validates :caption, length: { maximum: 5_000 }, allow_blank: true
  # A sanity bound, not a platform rule. 30 was Instagram's limit applied to
  # every platform, which is exactly the assumption the provider Capabilities
  # exist to avoid -- a LinkedIn-only post has no reason to obey Instagram's
  # cap. The real per-platform limit is enforced by Publishing::Preflight,
  # which reads it from the provider (spec 30).
  validates :hashtags, length: { maximum: 60 }

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
    update!(status: "publishing", publish_started_at: Time.current)
  end


  # What this post's status SHOULD be, read from its targets. Nil while any
  # target is still working.
  #
  # A post to three platforms can succeed twice and fail once, and one column
  # cannot describe that on its own -- so "published" is reserved for every
  # target actually landing, and two out of three is partially_published. That
  # state exists precisely so the screen can avoid the two available lies:
  # claiming it all went out, or claiming none of it did.
  def derived_status_from_targets
    targets = post_targets.reload
    return if targets.empty? || targets.any? { |target| !target.finished? }

    published = targets.count(&:published?)
    skipped = targets.count(&:skipped?)

    if published.zero? && skipped == targets.size then "reminded"
    elsif published.zero? then "failed"
    elsif published == targets.size then "published"
    else "partially_published"
    end
  end

  def first_published_at
    post_targets.filter_map(&:published_at).min
  end

  # True once it is finished and will not move again on its own.
  def settled? = published? || partially_published? || reminded? || failed? || cancelled?

  def publishable_targets = post_targets.select { |target| target.social_account&.usable_for_publishing? }
end
