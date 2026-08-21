module Publishing
  # Commits a post to a time, having first worked out whether it can actually go
  # out then.
  #
  # Refuses anything the owner can still fix, so a caption 40 characters over
  # Instagram's limit is caught here and not at 11am. What the owner cannot fix
  # -- Prachar having no connection to a platform yet -- is not a refusal: the
  # post is scheduled as a reminder, and says so.
  class SchedulePost < ApplicationCommand
    def initialize(post:, workspace:, actor:, at: nil, timezone: nil)
      @post = post
      @workspace = workspace
      @actor = actor
      @at = at || post.scheduled_at
      @timezone = timezone.presence || workspace.timezone
    end

    def call
      return Result.failure(:no_time) if @at.blank?
      return Result.failure(:in_the_past) if @at < 1.minute.ago
      return Result.failure(:no_targets) if @post.post_targets.empty?

      results = Preflight.new(@post).call
      fixable = results.flat_map(&:owner_fixable)
      return Result.failure(fixable) if fixable.any?

      mode = results.any?(&:publishable?) ? "automatic" : "reminder"

      @post.update!(publish_mode: mode)
      @post.schedule_for!(@at, timezone: @timezone)

      AuditEvent.record!(action: "post.scheduled", workspace: @workspace, actor_user: @actor,
                         auditable: @post,
                         metadata: { at: @at.iso8601, mode: mode, providers: @post.providers })

      Result.success(@post)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
