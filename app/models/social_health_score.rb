class SocialHealthScore < ApplicationRecord
  include WorkspaceOwned

  RATINGS = %w[needs_work fair good excellent].freeze

  enum :rating, RATINGS.index_by(&:itself), validate: true

  scope :recent_first, -> { order(computed_at: :desc) }

  validates :score, :coverage_percentage,
            numericality: { in: 0..100, only_integer: true }

  # A score built from part of the model must say so wherever it is shown.
  def partial? = coverage_percentage < 100

  def rating_label = rating.humanize

  def measured_components = components.select { |component| component["measured"] }
  def unavailable_components = components.reject { |component| component["measured"] }

  def findings_of(type)
    components.flat_map { |component| component["findings"].to_a }
              .select { |finding| finding["type"] == type }
              .map { |finding| finding["text"] }
  end

  def working = findings_of("working")
  def attention = findings_of("attention")
end
