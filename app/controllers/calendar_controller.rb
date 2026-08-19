class CalendarController < ApplicationController
  include WorkspaceScoping

  def show
    @calendar = Posts::CalendarQuery.new(
      workspace: current_workspace,
      view: params[:view],
      date: params[:date],
      provider: permitted_provider,
      status: permitted_status
    )

    @upcoming = current_workspace.posts.upcoming.chronological.limit(5)
                                 .includes(post_media: { media_asset: { file_attachment: :blob } })
    @connected_providers = current_workspace.social_accounts.connected.map(&:provider).uniq
  end

  private

  def permitted_provider
    params[:provider].presence_in(SocialProvider::Catalog::KEYS)
  end

  def permitted_status
    params[:status].presence_in(Post::STATUSES)
  end
end
