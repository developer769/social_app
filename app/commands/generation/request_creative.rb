module Generation
  # Starts a generation for a post.
  #
  # Output rows are created before any job runs, so the screen shows the full
  # set immediately and progress is countable from records rather than animated.
  class RequestCreative < ApplicationCommand
    def initialize(workspace:, post:, actor:, instructions: nil)
      @workspace = workspace
      @post = post
      @actor = actor
      @instructions = instructions
    end

    def call
      return Result.failure(:no_subject) if @post.subject.blank?

      template = @post.template
      format = template&.media_format || "image"

      # Refused before anything is enqueued, so a request that cannot possibly
      # succeed never looks like it is working. Both arms must return: an
      # earlier version only returned for video, so an image request against a
      # provider that cannot make images fell through and queued work that was
      # certain to fail three times over.
      return Result.failure(:format_unsupported) unless format == "image"
      return Result.failure(:provider_unavailable) unless provider.capabilities.generate_image?

      request = nil

      ActiveRecord::Base.transaction do
        request = @workspace.creative_requests.create!(
          post: @post, template: template, requested_by: @actor, subject: @post.subject,
          status: "generating", media_format: format,
          variant_count: format == "video" ? 1 : provider.capabilities.max_variants,
          instructions: @instructions, provider: provider.key, started_at: Time.current
        )

        request.variant_count.times do |index|
          request.creative_outputs.create!(position: index, status: "pending")
        end

        AuditEvent.record!(
          action: "creative.requested", workspace: @workspace, actor_user: @actor,
          auditable: request, metadata: { template: template&.slug, format: format }
        )
      end

      # Enqueued after commit, so a worker cannot start before its row is
      # visible to another connection.
      request.creative_outputs.each { |output| RunOutputJob.perform_later(output.id) }

      Result.success(request)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def provider = @provider ||= CreativeProvider::Registry.default
  end
end
