class ConversationsController < ApplicationController
  include WorkspaceScoping

  before_action :set_conversation

  def show
    @saved_replies = current_workspace.saved_replies.most_used
  end

  def reply
    result = Inbox::SendReply.call(conversation: @conversation, body: params[:body], actor: current_user)

    if result.success?
      redirect_to workspace_conversation_path(**slug, id: @conversation), notice: "Reply sent."
    else
      redirect_to workspace_conversation_path(**slug, id: @conversation), alert: reply_error(result.error)
    end
  end

  def close
    @conversation.close!(actor: current_user)
    redirect_to workspace_inbox_path(**slug), notice: "Marked done."
  end

  def reopen
    @conversation.reopen!
    redirect_to workspace_conversation_path(**slug, id: @conversation), notice: "Reopened."
  end

  private

  def set_conversation = @conversation = current_workspace.conversations.find(params[:id])

  def slug = { workspace_slug: current_workspace.slug }

  # A failed send leaves the message visible with its reason, so the error here
  # only has to name what went wrong once.
  def reply_error(error)
    case error
    when :empty then "Write something before sending."
    when :too_long then "That reply is too long to send."
    when :not_repliable then "#{@conversation.provider_name} does not allow replying from another app."
    when Message then error.error_message.presence || "That could not be sent."
    else "That could not be sent."
    end
  end
end
