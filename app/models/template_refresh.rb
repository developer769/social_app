class TemplateRefresh < ApplicationRecord
  STATUSES = %w[running complete failed].freeze

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :recent_first, -> { order(started_at: :desc) }

  def self.start!(source:)
    create!(source: source, status: "running", started_at: Time.current)
  end

  def finish!(added:, updated:, retired:)
    update!(status: "complete", added_count: added, updated_count: updated,
            retired_count: retired, finished_at: Time.current)
  end

  def fail!(message)
    update!(status: "failed", error_message: message.to_s.truncate(200), finished_at: Time.current)
  end

  def duration_seconds
    return if finished_at.blank?

    (finished_at - started_at).round
  end
end
