module Publishing
  # Everything that would stop a post reaching a platform, worked out BEFORE the
  # owner commits to a time.
  #
  # The alternative is discovering at 11am that a caption was 40 characters over
  # Instagram's limit, which is the moment a scheduling tool loses its whole
  # reason to exist. Every check here reads the provider's own declared
  # capabilities rather than assuming every platform behaves like Instagram
  # (spec 30).
  class Preflight
    # blocking: this target cannot publish at all.
    # advisory: it will publish, but something will be lost or trimmed.
    #
    # The code separates what the owner can fix from what only we can. A caption
    # over the limit is theirs to shorten; "no connection has been built" is
    # ours, and scheduling treats the two completely differently -- one is
    # refused, the other becomes a reminder.
    Issue = Struct.new(:severity, :code, :message, keyword_init: true) do
      def blocking? = severity == :blocking
      def ours? = code == :not_connected
    end

    Result = Struct.new(:target, :issues, keyword_init: true) do
      def blocking = issues.select(&:blocking?)
      def advisory = issues.reject(&:blocking?)
      def publishable? = blocking.empty?

      # Nothing is wrong with this post; Prachar simply cannot reach the
      # platform yet.
      def only_blocked_by_us? = blocking.any? && blocking.all?(&:ours?)
      def owner_fixable = blocking.reject(&:ours?)
    end

    def initialize(post)
      @post = post
    end

    def call = @post.post_targets.map { |target| examine(target) }

    # A post can go out automatically only if at least one platform can carry
    # it. Zero is the reminder case, not a failure.
    def any_publishable? = call.any?(&:publishable?)

    private

    def examine(target)
      account = target.social_account
      capabilities = account&.capabilities
      issues = []

      issues.concat(account_issues(account))
      issues.concat(media_issues(capabilities)) if capabilities
      issues.concat(caption_issues(target, capabilities)) if capabilities

      Result.new(target: target, issues: issues)
    end

    def account_issues(account)
      return [ blocking("This account is no longer connected.") ] if account.nil?

      issues = []

      unless account.connection_connected?
        issues << blocking("#{account.provider_name} is disconnected. Reconnect it to publish.")
      end

      if account.token_expired?
        issues << blocking("The #{account.provider_name} connection has expired. Reconnect it.")
      elsif account.token_expiring_soon?
        issues << advisory("The #{account.provider_name} connection expires soon. Reconnect it before it lapses.")
      end

      issues << blocking("#{account.provider_name} has not granted permission to post.") if account.permission_denied?

      # The honest one. Everything else on this list is the owner's to fix;
      # this one is ours, and saying so plainly is the whole point (spec 27, 30).
      if account.mocked?
        issues << blocking("Prachar cannot post to #{account.provider_name} yet. " \
                           "No connection to #{account.provider_name} has been built.",
                           code: :not_connected)
      end

      issues
    end

    def media_issues(capabilities)
      asset = @post.primary_media
      count = @post.post_media.size
      issues = []

      if asset.nil?
        issues << blocking("This platform needs a picture or a video.") unless capabilities.publish_text?
        return issues
      end

      if asset.video?
        issues << blocking("This platform cannot post video.") unless capabilities.publish_video?
        issues.concat(video_length_issues(asset, capabilities))
      elsif !capabilities.publish_image?
        issues << blocking("This platform cannot post pictures.")
      end

      if capabilities.max_media_count && count > capabilities.max_media_count
        issues << blocking("This platform takes at most #{capabilities.max_media_count} " \
                           "#{'item'.pluralize(capabilities.max_media_count)}, and this post has #{count}.")
      end

      # Spec 27 again, from the other end: a watermarked sample is not something
      # a business should be able to put in front of its customers.
      issues << blocking("This picture is a watermarked sample and cannot be published.") if sample?(asset)

      issues
    end

    def video_length_issues(asset, capabilities)
      limit = capabilities.max_video_seconds
      length = asset.duration_seconds
      return [] if limit.blank? || length.blank? || length <= limit

      [ blocking("This video is #{length.round} seconds and this platform allows #{limit}.") ]
    end

    def caption_issues(target, capabilities)
      issues = []
      caption = target.effective_caption.to_s
      limit = capabilities.max_caption_length

      if limit && caption.length > limit
        issues << blocking("The caption is #{caption.length} characters and this platform allows #{limit}.")
      end

      hashtag_limit = capabilities.max_hashtags
      if hashtag_limit && @post.hashtags.size > hashtag_limit
        issues << blocking("This post has #{@post.hashtags.size} hashtags and this platform allows #{hashtag_limit}.")
      end

      if @post.first_comment.present? && !capabilities.first_comment?
        issues << advisory("This platform has no first comment, so that text will not be posted.")
      end

      issues
    end

    # The sample flag, not merely "generated". A picture from a real generator
    # is a real picture; blocking those too would break publishing the day a
    # provider is contracted.
    def sample?(asset) = asset.metadata["sample"].present?

    def blocking(message, code: :blocked) = Issue.new(severity: :blocking, code: code, message: message)
    def advisory(message, code: :advisory) = Issue.new(severity: :advisory, code: code, message: message)
  end
end
