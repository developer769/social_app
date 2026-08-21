module Publishing
  # Finds posts whose moment has arrived and hands each one on.
  #
  # Runs every minute. It sweeps rather than relying on jobs scheduled far in
  # advance, because a job enqueued at scheduling time would outlive edits to
  # its own time, would survive the post being cancelled, and would vanish with
  # Redis. Re-deriving what is due from the database every minute has none of
  # those failure modes.
  class DispatchDueJob < ApplicationJob
    queue_as :default

    # A post whose time passed while the workers were down still goes out. Late
    # is a decision the owner can see and undo; silently skipped is not.
    # Anything older than this is left alone and reported instead, because
    # posting last week's Diwali offer today is worse than not posting it.
    STALE_AFTER = 6.hours

    def perform(now = Time.current)
      due = Post.due_for_publishing(now).order(:scheduled_at).limit(500)

      due.find_each do |post|
        if post.scheduled_at < now - STALE_AFTER
          expire(post)
        elsif claim(post)
          PublishPostJob.perform_later(post.id)
        end
      end
    end

    private

    # Claimed with a conditional UPDATE rather than by reading and then writing.
    # Two overlapping sweeps would otherwise both see the same scheduled post
    # and both enqueue it, and the second publish is the one that cannot be
    # taken back.
    def claim(post)
      Post.where(id: post.id, status: "scheduled")
          .update_all(status: "publishing", publish_started_at: Time.current, updated_at: Time.current) == 1
    end

    def expire(post)
      return unless Post.where(id: post.id, status: "scheduled").update_all(
        status: "failed", updated_at: Time.current
      ) == 1

      post.reload.post_targets.each do |target|
        target.mark_failed!(code: "missed_window",
                            message: "This was not published because its time passed while Prachar was not running.")
      end

      AuditEvent.record!(action: "post.missed_window", workspace: post.workspace, auditable: post,
                         metadata: { scheduled_at: post.scheduled_at&.iso8601 })
    end
  end
end
