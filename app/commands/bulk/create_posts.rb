module Bulk
  # Turns a batch of chosen styles into scheduled posts, in one transaction.
  #
  # All or nothing on purpose: a batch that half-created would leave the owner
  # with some posts scheduled, some not, and no way to tell which without
  # reading the calendar row by row.
  #
  # Generation is enqueued after the commit, one job per post, so a slow
  # provider cannot hold the whole batch open.
  class CreatePosts < ApplicationCommand
    MAX = 30

    Outcome = Struct.new(:posts, :plan, :generating, :needing_video, keyword_init: true) do
      def count = posts.size
    end

    # items: [{ template_id:, subject_type:, subject_id: }, ...]
    def initialize(workspace:, actor:, items:, starting: nil)
      @workspace = workspace
      @actor = actor
      @items = Array(items).first(MAX)
      @starting = starting
    end

    def call
      return Result.failure(:nothing_chosen) if @items.empty?

      templates = resolve_templates
      return Result.failure(:unknown_template) if templates.size != @items.size

      plan = Scheduling::MonthPlanner.new(workspace: @workspace, count: @items.size,
                                          starting: @starting).call
      return Result.failure(:no_slots) if plan.slots.empty?

      posts = []
      generating = []
      needing_video = []

      ActiveRecord::Base.transaction do
        @items.each_with_index do |item, index|
          slot = plan.slots[index]
          # Ran out of free slots inside the horizon. The rest are left as
          # drafts rather than crammed into a taken minute.
          break if slot.nil?

          template = templates.fetch(item[:template_id].to_s)
          post = build_post(template, item, slot)
          posts << post

          if template.media_format == "video"
            # Nothing can generate video, so this post is scheduled with its
            # slot and caption and waits for the owner's own file (spec 30).
            needing_video << post
          else
            generating << post
          end
        end

        AuditEvent.record!(
          action: "posts.bulk_created", workspace: @workspace, actor_user: @actor,
          metadata: { count: posts.size, from: plan.first_on&.iso8601, to: plan.last_on&.iso8601 }
        )
      end

      # After commit: a worker must never start on a post another connection
      # cannot see yet.
      generating.each { |post| request_pictures(post) }

      Result.success(Outcome.new(posts: posts, plan: plan, generating: generating,
                                 needing_video: needing_video))
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def resolve_templates
      ids = @items.map { |item| item[:template_id].to_s }
      ::Template.live.where(id: ids).index_by { |template| template.id.to_s }
    end

    def build_post(template, item, slot)
      subject = subject_for(item)

      post = @workspace.posts.create!(
        created_by: @actor, template: template, status: "draft", subject: subject,
        # Nothing here writes a caption. There is no text generator connected,
        # so pretending otherwise would be inventing a capability (spec 30).
        # The product's name is a real starting point and the owner edits it;
        # everything else comes from defaults they set themselves.
        caption: subject&.name,
        call_to_action: preference&.default_call_to_action,
        link_url: preference&.default_link_url,
        first_comment: preference&.default_first_comment
      )

      attach_targets(post)

      # Straight to scheduled: the whole point of a batch is not having to open
      # thirty posts and press the same button on each.
      post.update!(publish_mode: Publishing::Availability.mode_for(post))
      post.schedule_for!(slot, timezone: @workspace.timezone)
      post
    end

    # Every connected account that can carry this post's format. Read from each
    # provider's declared capabilities rather than assumed, so a video batch
    # does not target a platform that only takes pictures (spec 30).
    def attach_targets(post)
      video = post.template&.media_format == "video"

      connected_accounts.each do |account|
        capabilities = account.capabilities
        next if capabilities.nil?
        next unless video ? capabilities.publish_video? : capabilities.publish_image?

        post.post_targets.create!(social_account: account)
      end
    end

    def connected_accounts
      @connected_accounts ||= @workspace.social_accounts.connected.to_a
    end

    def preference = @preference ||= @workspace.posting_preference

    # Looked up through the workspace, so an id from somebody else's browser
    # simply is not found (spec 7).
    def subject_for(item)
      case item[:subject_type]
      when "Product" then @workspace.products.find_by(id: item[:subject_id])
      when "Service" then @workspace.services.find_by(id: item[:subject_id])
      end
    end

    def request_pictures(post)
      return if post.subject.blank?

      Generation::RequestCreative.call(workspace: @workspace, post: post, actor: @actor)
    end
  end
end
