module Posts
  # Creates or updates a post together with its media and its per-platform
  # targets, in one transaction: a post whose targets half-saved would publish
  # to an unpredictable subset.
  class SavePost < ApplicationCommand
    def initialize(workspace:, dto:, actor:, post: nil)
      @workspace = workspace
      @dto = dto
      @actor = actor
      @post = post
    end

    def call
      post = @post || @workspace.posts.new(created_by: @actor)
      creating = post.new_record?

      ActiveRecord::Base.transaction do
        post.assign_attributes(@dto.to_attributes)
        post.save!

        attach_media(post)
        replace_targets(post)

        AuditEvent.record!(
          action: creating ? "post.created" : "post.updated",
          workspace: @workspace, actor_user: @actor, auditable: post,
          metadata: { status: post.status, providers: post.providers }
        )
      end

      Result.success(post)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def attach_media(post)
      return if @dto.media_file.blank?

      asset = @workspace.media_assets.create!(
        uploaded_by: @actor,
        kind: @dto.media_kind,
        origin: "upload",
        content_type: @dto.media_file.content_type,
        byte_size: @dto.media_file.size,
        file: @dto.media_file
      )

      post.post_media.destroy_all
      post.post_media.create!(media_asset: asset, position: 0)
    end

    # Targets are rebuilt from the chosen accounts. Accounts that cannot carry
    # this post's media are refused here rather than failing at publish time.
    def replace_targets(post)
      accounts = @workspace.social_accounts.connected.where(id: @dto.social_account_ids)

      post.post_targets.where.not(social_account_id: accounts.map(&:id)).destroy_all

      accounts.each do |account|
        next unless account_can_carry?(account, post)

        post.post_targets.find_or_create_by!(social_account: account)
      end
    end

    def account_can_carry?(account, post)
      capabilities = account.capabilities
      return false if capabilities.nil?

      asset = post.post_media.first&.media_asset
      return true if asset.nil?

      asset.video? ? capabilities.publish_video? : capabilities.publish_image?
    end
  end
end
