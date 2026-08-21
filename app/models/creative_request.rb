class CreativeRequest < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[queued generating ready partially_ready failed cancelled].freeze

  belongs_to :post, optional: true
  belongs_to :template, optional: true
  belongs_to :requested_by, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :selected_output, class_name: "CreativeOutput", optional: true

  has_many :creative_outputs, -> { order(:position) }, dependent: :destroy, inverse_of: :creative_request

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :recent_first, -> { order(created_at: :desc) }

  validates :variant_count, numericality: { in: 1..3, only_integer: true }

  def finished? = ready? || partially_ready? || failed? || cancelled?

  # Real progress, counted from rows. There is no timer anywhere in this class
  # (spec 24).
  def finished_count = creative_outputs.count(&:finished?)
  def ready_count = creative_outputs.count(&:ready?)

  def progress_percentage
    total = creative_outputs.size
    return 0 if total.zero?

    ((finished_count.to_f / total) * 100).round
  end

  def usable_outputs = creative_outputs.select(&:ready?)

  # Derived from its outputs rather than set independently, so the parent can
  # never claim more than the variants actually produced.
  def settle!
    outputs = creative_outputs.reload
    return if outputs.empty? || outputs.any? { |output| !output.finished? }

    ready = outputs.count(&:ready?)

    update!(
      status: if ready.zero? then "failed"
              elsif ready == outputs.size then "ready"
              else "partially_ready"
              end,
      finished_at: Time.current
    )
  end

  def select!(output)
    raise ArgumentError, "that variant belongs to another request" unless output.creative_request_id == id
    raise ArgumentError, "that variant is not ready" unless output.ready?

    update!(selected_output: output)
  end
end
