module Posts
  # A copy to work from.
  #
  # Everything describing what the original IS comes across -- its words, its
  # picture, what it features, where it was going. Nothing describing what
  # already HAPPENED to it does: no date, no status, no remote id, no
  # generation history. A duplicate is a starting point, not a scheduled twin.
  class Duplicate < ApplicationCommand
    COPIED = %i[caption hashtags call_to_action link_url first_comment
                location_name template_id subject_type subject_id].freeze

    def initialize(post:, actor:)
      @post = post
      @actor = actor
    end

    def call
      copy = nil

      ActiveRecord::Base.transaction do
        copy = @post.workspace.posts.create!(
          @post.slice(*COPIED).merge(created_by: @actor, status: "draft")
        )

        # The same media rows, not new uploads: two posts pointing at one
        # picture is correct, and copying the file would double the storage for
        # no reason.
        @post.post_media.each do |media|
          copy.post_media.create!(media_asset: media.media_asset, position: media.position)
        end

        # Where it was going comes across; where it GOT to does not. Each target
        # is new, with its own idempotency key, so a copy can never be mistaken
        # for a retry of the original.
        @post.post_targets.each do |target|
          copy.post_targets.create!(social_account: target.social_account,
                                    caption_override: target.caption_override)
        end

        AuditEvent.record!(action: "post.duplicated", workspace: @post.workspace,
                           actor_user: @actor, auditable: copy,
                           metadata: { from_post_id: @post.id })
      end

      Result.success(copy)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
