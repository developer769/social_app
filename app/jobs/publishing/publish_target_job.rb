module Publishing
  # Publishes one post to one platform.
  #
  # One job per target rather than one per post, so a LinkedIn outage cannot
  # stop the Instagram copy going out, and so a retry retries only the platform
  # that actually failed.
  class PublishTargetJob < ApplicationJob
    queue_as :default

    ATTEMPTS = 4

    # The row is deliberately NOT marked failed on the way in here. Marking it
    # failed makes `finished?` true, and #perform returns early on a finished
    # target -- so every retry would be a no-op and one timeout would be
    # permanent. It is settled only once the attempts are genuinely spent.
    retry_on SocialProvider::TransientError,
             wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
      target = PostTarget.find_by(id: job.arguments.first)
      next if target.nil? || target.finished?

      target.mark_failed!(code: "provider_unavailable", message: error.message)
      Publishing::Settle.call(post: target.post)
    end

    def perform(target_id)
      target = PostTarget.find_by(id: target_id)
      return if target.nil? || target.finished?

      # The claim IS the check. A redelivered job, or a second worker handed the
      # same target, loses the claim and stops here rather than publishing a
      # second copy to a customer's feed.
      return unless target.claim_for_publishing!

      if over_daily_limit?(target)
        target.mark_skipped!(reason: daily_limit_message(target))
        return Settle.call(post: target.post)
      end

      publication = adapter_for(target).publish(request_for(target))

      target.mark_published!(remote_post_id: publication.remote_post_id, permalink: publication.permalink)
      target.update!(provider_response: publication.raw, last_attempt_at: Time.current)

      Settle.call(post: target.post)
    rescue SocialProvider::PermanentError => e
      # Never retried: a refusal, a bad caption or a missing connection fails
      # identically the second time.
      target&.mark_failed!(code: e.code.presence || "refused", message: e.message)
      Settle.call(post: target.post) if target
    rescue SocialProvider::TransientError
      # Released rather than left claimed: the lease exists to stop a SECOND
      # worker publishing, not to stop this job's own retry. Without this the
      # retry cannot re-claim and one timeout becomes permanent.
      target&.release_claim!
      raise
    rescue StandardError => e
      Rails.logger.error(message: "publishing failed", target_id: target_id,
                         workspace_id: target&.post&.workspace_id, error: e.class.name)
      target&.mark_failed!(code: "unexpected_error", message: "Something went wrong while posting.")
      Settle.call(post: target.post) if target
      raise
    end

    private

    def adapter_for(target)
      SocialProvider::Registry.for(target.provider,
                                   workspace: target.post.workspace,
                                   account: target.social_account)
    end

    def request_for(target)
      post = target.post

      SocialProvider::PublishRequestDto.new(
        caption: target.effective_caption,
        hashtags: post.hashtags,
        media: post.post_media.map(&:media_asset),
        link_url: post.link_url,
        first_comment: post.first_comment,
        location_name: post.location_name,
        # The key is stable per post and account, so a retry of the same work
        # reaches the provider as the same request rather than a new one.
        idempotency_key: target.idempotency_key,
        scheduled_at: post.scheduled_at
      )
    end

    # Platforms cap how much can go out in a day and answer with an opaque
    # error when the cap is hit. Counting our own publishes turns that into a
    # sentence the owner can act on.
    def over_daily_limit?(target)
      limit = target.capabilities&.daily_publish_limit
      return false if limit.blank?

      published_today(target) >= limit
    end

    def published_today(target)
      PostTarget.where(social_account_id: target.social_account_id, status: "published")
                .where(published_at: 24.hours.ago..)
                .count
    end

    def daily_limit_message(target)
      limit = target.capabilities.daily_publish_limit
      "#{target.provider_name} allows #{limit} #{'post'.pluralize(limit)} a day and that is used up. " \
        "Schedule this for tomorrow."
    end
  end
end
