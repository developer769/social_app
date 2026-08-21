module Publishing
  # Moves a post out of "publishing" once every platform has finished, and tells
  # people once.
  #
  # Called by each target as it finishes, so it must be safe to call repeatedly
  # and from several workers at once. It claims the transition with a
  # conditional UPDATE: without that, three targets finishing in the same second
  # would each see a settled post and each send its own "your post went out"
  # email for the same post.
  class Settle < ApplicationCommand
    def initialize(post:)
      @post = post
    end

    def call
      return Result.failure(:no_post) if @post.blank?

      post = @post.reload
      status = post.derived_status_from_targets
      return Result.failure(:still_working) if status.blank?

      published_at = post.first_published_at

      claimed = Post.where(id: post.id, status: "publishing").update_all(
        status: status,
        published_at: (published_at if %w[published partially_published].include?(status)),
        reminded_at: (Time.current if status == "reminded"),
        updated_at: Time.current
      )

      # Somebody else settled it first. Their worker sends the email, not this
      # one.
      return Result.failure(:already_settled) if claimed.zero?

      post.reload
      announce(post)
      Result.success(post)
    end

    private

    # The audit entry is written first and unconditionally. An email provider
    # having a bad afternoon must not cost us the record of what happened --
    # and it did once, before this was split: the status changed, the mailer
    # raised, and the job could not run again because the post had already
    # left the publishing state.
    def announce(post)
      AuditEvent.record!(
        action: "post.#{post.status}", workspace: post.workspace, auditable: post,
        metadata: { providers: post.providers,
                    published: post.post_targets.count(&:published?),
                    failed: post.post_targets.count(&:failed?),
                    skipped: post.post_targets.count(&:skipped?) }
      )

      notify(post)
    end

    CHANNELS = {
      "published" => %i[published published],
      "partially_published" => %i[published published],
      "failed" => %i[failed failed],
      "reminded" => %i[reminder time_to_post]
    }.freeze

    def notify(post)
      channel, mail = CHANNELS[post.status]
      return if channel.nil?

      NotificationPreference.recipients_for(post.workspace, channel).each do |user|
        PostMailer.public_send(mail, post, user).deliver_later
      end
    rescue StandardError => e
      # The post is settled and recorded either way. Losing the email is bad;
      # losing the transition would be worse.
      Rails.logger.error(message: "could not send post notification",
                         post_id: post.id, status: post.status, error: e.class.name)
    end
  end
end
