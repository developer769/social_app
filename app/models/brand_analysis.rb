class BrandAnalysis < ApplicationRecord
  include WorkspaceOwned

  STATUSES = %w[queued analyzing partially_complete complete failed].freeze

  # The order the tasks appear on screen.
  TASK_KEYS = %w[
    profile_health
    top_content
    posting_frequency
    audience_engagement
    best_posting_times
    content_categories
    brand_voice
  ].freeze

  belongs_to :requested_by, class_name: "User", optional: true
  has_many :tasks, class_name: "BrandAnalysisTask", dependent: :destroy, inverse_of: :brand_analysis

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :recent_first, -> { order(created_at: :desc) }

  # Real progress: the share of tasks that have actually finished. There is no
  # timer and no simulated percentage (spec 22).
  def progress_percentage
    total = tasks.size
    return 0 if total.zero?

    ((tasks.count { |task| task.finished? }.to_f / total) * 100).round
  end

  def finished? = complete? || partially_complete? || failed?

  # Called as each task finishes, so the parent's state always follows from its
  # children rather than being set independently.
  def refresh_status!
    reloaded = tasks.reload
    return if reloaded.any? { |task| !task.finished? }

    analysed = reloaded.count { |task| task.outcome == "analysed" }
    failed = reloaded.count { |task| task.status == "failed" }

    new_status =
      if failed == reloaded.size then "failed"
      elsif analysed == reloaded.size then "complete"
      else "partially_complete"
      end

    update!(status: new_status, finished_at: Time.current)
  end
end
