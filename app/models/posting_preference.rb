class PostingPreference < ApplicationRecord
  include WorkspaceOwned

  CAPTION_STYLES = { "short" => "Short & sweet", "balanced" => "Balanced", "storytelling" => "Storytelling" }.freeze
  HASHTAG_STYLES = { "none" => "None", "minimal" => "Minimal", "balanced" => "Balanced", "trending" => "Trending" }.freeze
  EMOJI_LEVELS = { "none" => "None", "minimal" => "Minimal", "moderate" => "Moderate", "expressive" => "Expressive" }.freeze
  DAY_NAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
  MAX_KEYWORDS = 20

  enum :caption_style, CAPTION_STYLES.keys.index_by(&:itself), prefix: :caption, validate: true
  enum :hashtag_style, HASHTAG_STYLES.keys.index_by(&:itself), prefix: :hashtags, validate: true
  enum :emoji_level, EMOJI_LEVELS.keys.index_by(&:itself), prefix: :emoji, validate: true

  validates :posts_per_week, numericality: { in: 1..21, only_integer: true }
  validates :preferred_time, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/, message: "must be a time like 10:00" }
  validate :days_are_real_days
  validate :lists_are_within_limits

  def caption_style_label = CAPTION_STYLES.fetch(caption_style)
  def hashtag_style_label = HASHTAG_STYLES.fetch(hashtag_style)
  def emoji_level_label = EMOJI_LEVELS.fetch(emoji_level)

  def preferred_day_names = preferred_days.sort.map { |day| DAY_NAMES[day] }.compact

  def schedule_summary
    days = preferred_day_names
    frequency = "#{posts_per_week} #{'post'.pluralize(posts_per_week)} a week"

    return frequency if days.empty?

    "#{frequency}, usually #{days.to_sentence} around #{preferred_time}"
  end

  private

  def days_are_real_days
    return if preferred_days.all? { |day| (0..6).cover?(day) }

    errors.add(:preferred_days, "contains a day that does not exist")
  end

  def lists_are_within_limits
    errors.add(:brand_keywords, "can have at most #{MAX_KEYWORDS}") if brand_keywords.size > MAX_KEYWORDS
    errors.add(:avoid_terms, "can have at most #{MAX_KEYWORDS}") if avoid_terms.size > MAX_KEYWORDS
  end
end
