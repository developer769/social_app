class InboxController < ApplicationController
  include WorkspaceScoping

  KINDS = Conversation::KINDS

  def show
    @reach = Inbox::ReachQuery.new(workspace: current_workspace)
    @kind = params[:kind].presence_in(KINDS)
    @provider = params[:provider].presence_in(SocialProvider::Catalog.keys)

    @conversations = current_workspace.conversations
                                      .includes(:social_account, :messages)
                                      .of_kind(@kind)
                                      .for_provider(@provider)
                                      .where(status: status_filter)
                                      .newest_first
                                      .limit(100)

    @saved_replies = current_workspace.saved_replies.most_used.limit(6)
    @open_count = current_workspace.conversations.open.count
  end

  private

  # Closed threads are hidden by default rather than deleted: an inbox that
  # shows everything ever received stops being a queue.
  def status_filter = params[:status] == "closed" ? "closed" : "open"
end
