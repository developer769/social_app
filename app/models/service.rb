class Service < ApplicationRecord
  include WorkspaceOwned
  include Positioned

  AVAILABILITY_STATUSES = %w[available unavailable coming_soon].freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGE_MAX_BYTES = 2.megabytes

  has_one_attached :cover_image

  enum :availability_status, AVAILABILITY_STATUSES.index_by(&:itself), prefix: :availability, validate: true

  scope :featured, -> { where(featured: true) }
  scope :active, -> { where(active: true) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 200 }, allow_blank: true
  validates :starting_price_minor, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :currency, presence: true, length: { is: 3 }
  validates :duration_min_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :duration_max_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true

  validate :duration_range_is_ordered
  validate :booking_url_is_http
  validate :cover_image_is_supported

  def starting_price
    return if starting_price_minor.nil?

    Money.new(minor_units: starting_price_minor, currency: currency)
  end

  # "1 day", "2-3 days", "from 3 days". Matches the wording in the designs.
  def duration_label
    return if duration_min_days.blank?

    return "#{duration_min_days} #{'day'.pluralize(duration_min_days)}" if duration_max_days.blank? || duration_max_days == duration_min_days

    "#{duration_min_days}\u2013#{duration_max_days} days"
  end

  private

  def duration_range_is_ordered
    return if duration_min_days.blank? || duration_max_days.blank?

    errors.add(:duration_max_days, "must be at least the minimum") if duration_max_days < duration_min_days
  end

  def booking_url_is_http
    return if booking_url.blank?

    errors.add(:booking_url, "must start with http:// or https://") unless URI.parse(booking_url).is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    errors.add(:booking_url, "is not a valid address")
  end

  def cover_image_is_supported
    return unless cover_image.attached?

    errors.add(:cover_image, "must be a PNG, JPG or WebP") unless IMAGE_CONTENT_TYPES.include?(cover_image.content_type)
    errors.add(:cover_image, "must be 2MB or smaller") if cover_image.byte_size > IMAGE_MAX_BYTES
  end
end
