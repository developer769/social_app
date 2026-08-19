# One platform's copy of a post.
#
# Exists so partial success is representable: a post to Instagram, Facebook and
# LinkedIn can succeed twice and fail once, and each outcome needs its own
# status, its own error and its own idempotency key.
class PostTarget < ApplicationRecord
  STATUSES = %w[pending validating publishing published failed skipped].freeze

  belongs_to :post
  belongs_to :social_account

  enum :status, STATUSES.index_by(&:itself), validate: true

  before_validation :assign_provider, on: :create
  before_validation :assign_idempotency_key, on: :create

  validates :provider, presence: true, inclusion: { in: SocialProvider::Catalog::KEYS }
  validates :idempotency_key, presence: true, uniqueness: true

  delegate :capabilities, :provider_name, to: :social_account

  def finished? = published? || failed? || skipped?

  def effective_caption = caption_override.presence || post.caption

  def start_publishing!
    update!(status: "publishing", attempt_count: attempt_count + 1)
  end

  def mark_published!(remote_post_id:, permalink: nil)
    update!(status: "published", remote_post_id: remote_post_id, permalink: permalink,
            published_at: Time.current, error_code: nil, error_message: nil)
  end

  def mark_failed!(code:, message:)
    update!(status: "failed", error_code: code, error_message: message.to_s.truncate(200))
  end

  def mark_skipped!(reason:)
    update!(status: "skipped", error_code: "skipped", error_message: reason.to_s.truncate(200))
  end

  private

  def assign_provider
    self.provider ||= social_account&.provider
  end

  # Derived from the post and the account rather than random, so a retry of the
  # same work reuses the same key and cannot publish twice.
  def assign_idempotency_key
    self.idempotency_key ||= Digest::SHA256.hexdigest("post:#{post_id}:account:#{social_account_id}").first(32)
  end
end
