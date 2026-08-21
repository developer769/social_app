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

  # How long one worker's claim on this target is respected. Long enough to
  # cover a slow upload to a platform, short enough that a worker killed
  # mid-publish does not strand the post for ever.
  PUBLISH_LEASE = 15.minutes

  # Claims this target for publishing, atomically, and answers whether the claim
  # was won.
  #
  # Reading the status and then publishing is not enough: two workers handed the
  # same target both see "not finished", both call the provider, and the
  # customer's followers see the post twice. That is the worst thing this system
  # could do, and it cannot be prevented by checking first -- only by making the
  # check and the claim the same statement.
  #
  # A stale claim can be taken over, so a worker killed mid-publish does not
  # leave the target stuck in "publishing" until somebody notices.
  def claim_for_publishing!
    now = Time.current

    claimed = PostTarget.where(id: id).where(
      "status IN ('pending','validating') OR "       "(status = 'publishing' AND (last_attempt_at IS NULL OR last_attempt_at < :stale))",
      stale: now - PUBLISH_LEASE
    ).update_all([
      "status = 'publishing', attempt_count = attempt_count + 1, last_attempt_at = ?, updated_at = ?",
      now, now
    ])

    reload if claimed == 1
    claimed == 1
  end

  # Hands the claim back after a failure that did not reach the platform, so
  # this job's own retry can pick it up again rather than waiting out the lease.
  #
  # Safe precisely because of the idempotency key: if the request did in fact
  # arrive and the answer was merely lost, the provider recognises the retry as
  # the same request rather than as a second post.
  def release_claim!
    return unless publishing?

    update_columns(status: "pending", last_attempt_at: Time.current, updated_at: Time.current)
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
