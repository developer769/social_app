module Generation
  # Produces one variant.
  #
  # Safe to run twice: a finished output is left alone, so a Sidekiq retry
  # cannot spend a second generation on work already done. That matters more
  # here than elsewhere, because a real provider charges per call.
  class RunOutputJob < ApplicationJob
    queue_as :default

    ATTEMPTS = 3

    # The row is deliberately NOT marked failed on the way in here. Marking it
    # failed makes `finished?` true, and the very next line of #perform returns
    # early on a finished output -- so every retry would be a no-op and the
    # first blip would be permanent. It is settled only once the attempts are
    # actually spent.
    retry_on CreativeProvider::TransientError,
             wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
      output = CreativeOutput.find_by(id: job.arguments.first)
      next if output.nil? || output.finished?

      output.fail!(outcome: "provider_error", message: error.message)
      request = output.creative_request.reload
      request.settle!
      Rails.logger.error(message: "creative generation gave up after retries",
                         output_id: output.id, error: error.class.name)
    end

    def perform(output_id)
      output = CreativeOutput.find_by(id: output_id)
      return if output.nil? || output.finished?

      output.start!
      request = output.creative_request

      result = provider_for(request).generate(brief: BriefBuilder.new(request: request).call,
                                              variant_index: output.position)
      asset = persist(result, request)
      output.succeed!(media_asset: asset, metadata: result.metadata)
    rescue CreativeProvider::PermanentError => e
      # Never retried: retrying a refusal burns money and fails identically.
      output&.fail!(outcome: e.code == "video_unsupported" ? "unavailable" : "refused", message: e.message)
    rescue CreativeProvider::TransientError
      # Left as it is and re-raised, so retry_on above can actually retry it.
      raise
    rescue StandardError => e
      # Recorded and not retried: an unexpected error repeats identically, and a
      # real provider charges for every attempt.
      Rails.logger.error(message: "creative generation failed", output_id: output_id,
                         workspace_id: output&.creative_request&.workspace_id, error: e.class.name)
      output&.fail!(outcome: "provider_error", message: e.message)
      raise
    ensure
      if output
        request = output.creative_request.reload
        request.settle!
        broadcast(request)
      end
    end

    private

    def provider_for(request) = CreativeProvider::Registry.for(request.provider)

    def persist(result, request)
      request.workspace.media_assets.create!(
        uploaded_by: request.requested_by,
        kind: "image", origin: "generated",
        content_type: result.content_type, width: result.width, height: result.height,
        metadata: result.metadata.merge("sample" => result.sample?),
        file: { io: result.io, filename: result.filename, content_type: result.content_type }
      )
    end

    def broadcast(request)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ request.workspace, :creative_request, request.id ],
        target: "creative-request",
        partial: "creative_requests/panel",
        locals: { request: request }
      )
    rescue StandardError => e
      # Live updating is a convenience. A broadcast failure must not undo a
      # generation that succeeded, or mark a finished variant as failed.
      Rails.logger.warn(message: "could not broadcast generation progress",
                        request_id: request.id, error: e.class.name)
    end
  end
end
