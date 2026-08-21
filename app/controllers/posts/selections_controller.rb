module Posts
  # Choosing one of the generated versions.
  class SelectionsController < ApplicationController
    include WorkspaceScoping

    def create
      request = current_workspace.creative_requests.find(params[:creative_request_id])
      output = request.creative_outputs.find(params[:id])

      ActiveRecord::Base.transaction do
        request.select!(output)
        attach_to_post(request, output)
      end

      redirect_to edit_workspace_post_path(workspace_slug: current_workspace.slug, id: request.post_id),
                  notice: "Version #{output.position + 1} chosen. Add your caption and schedule it."
    rescue ArgumentError => e
      redirect_to workspace_post_creative_path(workspace_slug: current_workspace.slug,
                                               post_id: request.post_id),
                  alert: e.message
    end

    private

    # Replaces whatever the post had, so choosing twice cannot leave two
    # pictures attached.
    def attach_to_post(request, output)
      post = request.post
      return if post.blank?

      post.post_media.destroy_all
      post.post_media.create!(media_asset: output.media_asset, position: 0)
    end
  end
end
