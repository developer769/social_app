class CreateController < ApplicationController
  include WorkspaceScoping

  # The two ways a post starts. Both end at the same place, so this exists to
  # make the choice obvious rather than to add a step.
  def show
    @recent = current_workspace.posts.where(status: "draft").order(updated_at: :desc).limit(3)
    @has_catalog = current_workspace.products.any? || current_workspace.services.any?
  end
end
