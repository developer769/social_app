class Product < ApplicationRecord
  include WorkspaceOwned
  include Positioned

  AVAILABILITY_STATUSES = %w[available unavailable coming_soon].freeze
  STOCK_STATUSES = %w[in_stock low_stock out_of_stock].freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGE_MAX_BYTES = 2.megabytes

  has_one_attached :image

  enum :availability_status, AVAILABILITY_STATUSES.index_by(&:itself), prefix: :availability, validate: true
  enum :stock_status, STOCK_STATUSES.index_by(&:itself), prefix: :stock, validate: true

  scope :featured, -> { where(featured: true) }
  scope :active, -> { where(active: true) }

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 200 }, allow_blank: true
  validates :price_minor, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :currency, presence: true, length: { is: 3 }

  validate :url_is_http
  validate :image_is_supported

  def price
    return if price_minor.nil?

    Money.new(minor_units: price_minor, currency: currency)
  end

  private

  def url_is_http
    return if url.blank?

    errors.add(:url, "must start with http:// or https://") unless URI.parse(url).is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid address")
  end

  def image_is_supported
    return unless image.attached?

    errors.add(:image, "must be a PNG, JPG or WebP") unless IMAGE_CONTENT_TYPES.include?(image.content_type)
    errors.add(:image, "must be 2MB or smaller") if image.byte_size > IMAGE_MAX_BYTES
  end
end
