module Gallery
  class UsesController < ApplicationController
    include WorkspaceScoping

    # Starts a post from a style.
    #
    # Creates the draft and moves straight into choosing what the post should
    # feature. Creating the post here rather than later makes that choice an
    # update rather than an insert, which removes the double-draft race by
    # construction.
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

      redirect_to new_workspace_post_creative_path(workspace_slug: current_workspace.slug, post_id: post),
                  notice: "Using #{template.name}. Choose what it should feature."
    end
  end
end
