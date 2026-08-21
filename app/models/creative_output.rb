class CreativeOutput < ApplicationRecord
  STATUSES = %w[pending generating ready failed].freeze
  OUTCOMES = %w[generated refused provider_error unavailable].freeze

  belongs_to :creative_request
  belongs_to :media_asset, optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  def finished? = ready? || failed?

  def start!
    update!(status: "generating")
  end

  def succeed!(media_asset:, metadata: {})
    update!(status: "ready", outcome: "generated", media_asset: media_asset,
            metadata: metadata, finished_at: Time.current)
  end

  # A failure records WHY, so a content refusal reads differently from a
  # provider being down, and only one of them is worth retrying.
  def fail!(outcome:, message:)
    raise ArgumentError, "unknown outcome: #{outcome}" unless OUTCOMES.include?(outcome.to_s)

    update!(status: "failed", outcome: outcome.to_s,
            error_message: message.to_s.truncate(200), finished_at: Time.current)
  end

  def failure_label
    case outcome
    when "refused" then "The generator would not make this one"
    when "provider_error" then "The generator had a problem"
    when "unavailable" then "Not available yet"
    else "Could not be made"
    end
  end

  # Everything produced while no real provider exists is a sample, and a sample
  # must never be publishable.
  def sample? = metadata["watermarked"].present? || CreativeProvider::Registry.mocked?
end
