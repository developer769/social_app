class BrandAnalysisTask < ApplicationRecord
  STATUSES = %w[queued analyzing complete failed].freeze
  OUTCOMES = %w[analysed insufficient_data not_supported error].freeze

  # Wording shown on screen, kept beside the keys so the view never invents its own.
  LABELS = {
    "profile_health" => [ "Profile health", "Checking profile completeness, branding and consistency." ],
    "top_content" => [ "Top-performing content", "Identifying your best content based on engagement." ],
    "posting_frequency" => [ "Posting frequency", "Analysing how often you post and consistency patterns." ],
    "audience_engagement" => [ "Audience engagement", "Measuring likes, comments, shares and interactions." ],
    "best_posting_times" => [ "Best posting times", "Finding when your audience is most active." ],
    "content_categories" => [ "Content categories", "Determining your top content themes and topics." ],
    "brand_voice" => [ "Brand voice", "Understanding your tone, style and messaging." ]
  }.freeze

  belongs_to :brand_analysis

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :task_key, presence: true, inclusion: { in: BrandAnalysis::TASK_KEYS },
                       uniqueness: { scope: :brand_analysis_id }

  def label = LABELS.fetch(task_key, [ task_key.humanize, nil ]).first
  def summary = LABELS.fetch(task_key, [ nil, nil ]).last

  def finished? = complete? || failed?

  def start!
    update!(status: "analyzing", started_at: Time.current)
  end

  # A finished task always records why it produced what it did, so "we found
  # nothing" is never mistaken for "we measured zero" (spec 27).
  def finish!(outcome:, result: {}, error_message: nil)
    raise ArgumentError, "unknown outcome: #{outcome}" unless OUTCOMES.include?(outcome.to_s)

    update!(
      status: outcome.to_s == "error" ? "failed" : "complete",
      outcome: outcome.to_s,
      result: result,
      error_message: error_message,
      finished_at: Time.current
    )
  end

  # What the owner is told about this task, in plain words.
  def outcome_label
    case outcome
    when "analysed" then "Completed"
    when "insufficient_data" then "Not enough data yet"
    when "not_supported" then "Needs a connected account"
    when "error" then "Could not complete"
    else status == "analyzing" ? "In progress" : "Pending"
    end
  end

  def outcome_tone
    case outcome
    when "analysed" then :success
    when "insufficient_data", "not_supported" then :neutral
    when "error" then :danger
    else :info
    end
  end
end
