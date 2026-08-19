class Template < ApplicationRecord
  MEDIA_FORMATS = %w[image video].freeze
  SOURCES = %w[curated trend_feed partner].freeze

  CONTENT_CATEGORIES = {
    "festive" => "Festive",
    "offer" => "Offer",
    "new_launch" => "New Launch",
    "behind_the_scenes" => "Behind the Scenes",
    "product_showcase" => "Product Showcase",
    "reels_style" => "Reels-style",
    "menu" => "Menu",
    "tips" => "Tips",
    "educational" => "Educational",
    "testimonials" => "Testimonials"
  }.freeze

  has_one_attached :preview

  has_many :template_favourites, dependent: :destroy

  enum :media_format, MEDIA_FORMATS.index_by(&:itself), prefix: :format, validate: true
  enum :source, SOURCES.index_by(&:itself), prefix: :source, validate: true

  scope :live, -> { where(active: true, retired_at: nil) }
  scope :photos, -> { where(media_format: "image") }
  scope :videos, -> { where(media_format: "video") }
  scope :in_category, ->(category) { where(content_category: category) }
  scope :free, -> { where(premium: false) }

  # Ordering is deliberately explicit about what it is measuring.
  #
  # NULLS LAST matters: a template with no trend data must not be ordered as
  # though it scored zero. Until a feed supplies real scores every score is
  # null, so this degrades to the curated order rather than inventing a ranking
  # (spec 27).
  scope :most_trending, -> { order(Arel.sql("trend_score DESC NULLS LAST, position ASC, id ASC")) }
  scope :most_used, -> { order(generations_count: :desc, position: :asc, id: :asc) }
  scope :newest_first, -> { order(first_seen_at: :desc, id: :desc) }
  scope :curated_order, -> { order(:position, :id) }

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
  validates :content_category, inclusion: { in: CONTENT_CATEGORIES.keys }
  validates :duration_seconds, presence: true, if: :format_video?
  validates :duration_seconds, numericality: { greater_than: 0 }, allow_nil: true
  validates :trend_score, numericality: { in: 0..100 }, allow_nil: true

  def category_label = CONTENT_CATEGORIES.fetch(content_category, content_category.humanize)

  def retired? = retired_at.present?
  def live? = active? && !retired?

  # True only when a source has actually supplied a popularity signal. The
  # gallery uses this to decide whether it may say "trending" at all.
  def trend_ranked? = trend_score.present?

  def duration_label
    return if duration_seconds.blank?

    "#{duration_seconds / 60}:#{format('%02d', duration_seconds % 60)}"
  end

  # Which connected accounts could actually carry this template. A video
  # template is unusable on Google Business Profile, and an image template is
  # unusable on TikTok, so the answer has to come from capabilities rather than
  # from the supported_platforms list alone (spec 30).
  def publishable_on?(provider_key)
    capabilities = SocialProvider::Catalog.capabilities_for(provider_key)
    return false if capabilities.nil?

    format_video? ? capabilities.publish_video? : capabilities.publish_image?
  end

  def compatible_providers
    SocialProvider::Catalog.keys.select { |key| publishable_on?(key) }
  end

  def favourited_by?(workspace)
    return false if workspace.nil?

    template_favourites.exists?(workspace: workspace)
  end

  def retire!(at: Time.current)
    update!(retired_at: at, active: false)
  end

  def mark_seen!(trend_score: nil)
    attributes = { last_refreshed_at: Time.current, retired_at: nil, active: true }
    attributes[:trend_score] = trend_score if trend_score
    attributes[:trend_scored_at] = Time.current if trend_score
    update!(**attributes)
  end
end
