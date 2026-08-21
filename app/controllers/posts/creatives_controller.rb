module Posts
  # Generating a creative for a post, and choosing between the results.
  class CreativesController < ApplicationController
    include WorkspaceScoping

    before_action :set_post

    def show
      @request = @post.creative_requests.recent_first.first
      redirect_to new_workspace_post_creative_path(**slug, post_id: @post) and return if @request.nil?
    end

    def new
      @products = current_workspace.products.active.in_display_order
      @services = current_workspace.services.active.in_display_order
    end

    def create
      assign_subject

      result = Generation::RequestCreative.call(
        workspace: current_workspace, post: @post, actor: current_user,
        instructions: params[:instructions]
      )

      if result.success?
        redirect_to workspace_post_creative_path(**slug, post_id: @post)
      else
        redirect_to new_workspace_post_creative_path(**slug, post_id: @post),
                    alert: failure_message(result.error)
      end
    end

    private

    def set_post = @post = current_workspace.posts.find(params[:post_id])

    def slug = { workspace_slug: current_workspace.slug }

    # The radio sends "Product:12". Looked up through the workspace, so an id
    # belonging to another tenant simply is not found.
    def assign_subject
      type, id = params[:subject].to_s.split(":", 2)
      return if id.blank?

      subject =
        case type
        when "Product" then current_workspace.products.find_by(id: id)
        when "Service" then current_workspace.services.find_by(id: id)
        end

      @post.update!(subject: subject) if subject
    end

    def failure_message(error)
      case error
      when :no_subject then "Choose what this post should feature first."
      when :format_unsupported then "Video generation is not available yet."
      when :provider_unavailable then "Picture generation is not available right now."
      else "That could not be started."
      end
    end
  end
end
