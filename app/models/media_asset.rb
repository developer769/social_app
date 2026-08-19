class MediaAsset < ApplicationRecord
  include WorkspaceOwned

  KINDS = %w[image video].freeze
  ORIGINS = %w[upload generated].freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  VIDEO_CONTENT_TYPES = %w[video/mp4 video/quicktime video/webm].freeze
  IMAGE_MAX_BYTES = 15.megabytes
  VIDEO_MAX_BYTES = 200.megabytes

  has_one_attached :file

  belongs_to :uploaded_by, class_name: "User", optional: true

  has_many :post_media, dependent: :destroy
  has_many :posts, through: :post_media

  enum :kind, KINDS.index_by(&:itself), prefix: :kind, validate: true
  enum :origin, ORIGINS.index_by(&:itself), prefix: :origin, validate: true

  scope :newest_first, -> { order(created_at: :desc) }

  validate :file_is_present_and_supported

  def image? = kind_image?
  def video? = kind_video?

  def aspect_ratio
    return if width.blank? || height.blank? || height.zero?

    (width.to_f / height).round(3)
  end

  def duration_seconds
    return if duration_ms.blank?

    (duration_ms / 1000.0).round
  end

  private

  def file_is_present_and_supported
    return errors.add(:file, "is required") unless file.attached?

    allowed = kind_video? ? VIDEO_CONTENT_TYPES : IMAGE_CONTENT_TYPES
    maximum = kind_video? ? VIDEO_MAX_BYTES : IMAGE_MAX_BYTES

    errors.add(:file, "is not a supported #{kind}") unless allowed.include?(file.content_type)
    errors.add(:file, "is too large") if file.byte_size.to_i > maximum
  end
end
