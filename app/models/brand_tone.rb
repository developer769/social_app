class BrandTone < ApplicationRecord
  include WorkspaceOwned

  TONES = %w[friendly elegant playful professional premium educational bold minimal].freeze

  enum :tone, TONES.index_by(&:itself), validate: true

  validates :tone, uniqueness: { scope: :workspace_id }

  def label = tone.humanize
end
