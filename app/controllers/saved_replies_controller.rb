class SavedRepliesController < ApplicationController
  include WorkspaceScoping

  before_action :set_reply, only: %i[edit update destroy]

  def index
    @saved_replies = current_workspace.saved_replies.in_display_order
  end

  def new
    @saved_reply = current_workspace.saved_replies.new
  end

  def create
    # Built detached and assigned, rather than through the association: building
    # through it appends to the loaded collection, and autosave then validates
    # an unsaved record on every later write to the workspace.
    @saved_reply = SavedReply.new(reply_params)
    @saved_reply.workspace = current_workspace
    @saved_reply.created_by = current_user
    @saved_reply.position = current_workspace.saved_replies.maximum(:position).to_i + 1

    if @saved_reply.save
      redirect_to workspace_saved_replies_path(**slug), notice: "Saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @saved_reply.update(reply_params)
      redirect_to workspace_saved_replies_path(**slug), notice: "Updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @saved_reply.destroy!
    redirect_to workspace_saved_replies_path(**slug), notice: "Deleted."
  end

  private

  def set_reply = @saved_reply = current_workspace.saved_replies.find(params[:id])

  def slug = { workspace_slug: current_workspace.slug }

  def reply_params = params.require(:saved_reply).permit(:title, :body)
end
