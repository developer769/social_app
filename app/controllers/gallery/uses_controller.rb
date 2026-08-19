module Gallery
  class UsesController < ApplicationController
    include WorkspaceScoping

    # Starts a post from a style.
    #
    # Generation is not connected yet, so this creates the draft and takes the
    # owner to it, where they attach their own picture. When a generation
    # provider lands, this is where it hooks in -- the draft already knows which
    # style it came from.
    def create
      template = Template.published.find_by!(slug: params[:slug])

      post = current_workspace.posts.create!(
        created_by: current_user,
        template: template,
        status: "draft",
        caption: nil
      )

      AuditEvent.record!(
        action: "post.started_from_template",
        workspace: current_workspace, actor_user: current_user, auditable: post,
        metadata: { template: template.slug }
      )

      redirect_to edit_workspace_post_path(workspace_slug: current_workspace.slug, id: post),
                  notice: "Started a post from #{template.name}. Add your picture and caption."
    end
  end
end
