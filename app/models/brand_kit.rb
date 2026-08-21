class BrandKit < ApplicationRecord
  include WorkspaceOwned

  HEX = /\A#[0-9a-fA-F]{6}\z/
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  MAX_BYTES = 5.megabytes

  # Three logo variants, because a creative needs a different mark on a dark
  # ground than on a light one, and neither works as a favicon.
  has_one_attached :logo
  has_one_attached :logo_on_dark
  has_one_attached :icon

  normalizes :primary_color, with: ->(value) { value.presence&.strip&.downcase }
  normalizes :secondary_color, with: ->(value) { value.presence&.strip&.downcase }
  normalizes :accent_color, with: ->(value) { value.presence&.strip&.downcase }

  validates :primary_color, :secondary_color, :accent_color,
            format: { with: HEX, message: "must be a colour like #341044" }, allow_blank: true
  validates :usage_notes, length: { maximum: 500 }, allow_blank: true

  validate :attachments_are_supported

  def colors
    { "Primary" => primary_color, "Secondary" => secondary_color, "Accent" => accent_color }.compact_blank
  end

  def complete? = colors.any? && logo.attached?

  private

  def attachments_are_supported
    { logo: logo, logo_on_dark: logo_on_dark, icon: icon }.each do |name, attachment|
      next unless attachment.attached?

      errors.add(name, "must be a PNG, JPG, SVG or WebP") unless IMAGE_CONTENT_TYPES.include?(attachment.content_type)
      errors.add(name, "must be 5MB or smaller") if attachment.byte_size > MAX_BYTES
    end
  end
end
