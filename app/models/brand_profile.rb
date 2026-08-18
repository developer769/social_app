class BrandProfile < ApplicationRecord
  include WorkspaceOwned

  BUSINESS_TYPES = %w[sole_proprietor small_business partnership private_limited llp other].freeze

  has_one_attached :logo

  enum :business_type, BUSINESS_TYPES.index_by(&:itself), validate: { allow_nil: true }

  normalizes :contact_email, with: ->(value) { value.presence&.strip&.downcase }
  normalizes :website_url, with: ->(value) { value.presence&.strip }

  validates :about, length: { maximum: 500 }, allow_nil: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  validate :website_url_is_http
  validate :logo_is_a_supported_image

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_BYTES = 2.megabytes

  # Completeness drives the onboarding progress indicator and the social health
  # score, so it is computed from real data rather than a stored flag.
  def completeness
    filled = [ category, business_type, contact_email, phone, city, about ].count(&:present?)
    total = 6
    ((filled.to_f / total) * 100).round
  end

  private

  def website_url_is_http
    return if website_url.blank?

    uri = URI.parse(website_url)
    errors.add(:website_url, "must start with http:// or https://") unless uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    errors.add(:website_url, "is not a valid address")
  end

  def logo_is_a_supported_image
    return unless logo.attached?

    errors.add(:logo, "must be a PNG, JPG, SVG or WebP") unless LOGO_CONTENT_TYPES.include?(logo.content_type)
    errors.add(:logo, "must be 2MB or smaller") if logo.byte_size > LOGO_MAX_BYTES
  end
end
