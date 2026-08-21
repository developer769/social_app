class PostsController < ApplicationController
  include WorkspaceScoping

  before_action :set_post, only: %i[show edit update schedule unschedule cancel destroy]

  def new
    @post = current_workspace.posts.new(status: "draft")
    @accounts = connectable_accounts
  end

  def create
    result = Posts::SavePost.call(workspace: current_workspace, dto: build_dto, actor: current_user)

    if result.success?
      redirect_to after_save_path(result.value), notice: success_notice(result.value)
    else
      @post = result.error
      @accounts = connectable_accounts
      render :new, status: :unprocessable_content
    end
  end

  def show
    @accounts = connectable_accounts
    @preflight = Publishing::Preflight.new(@post).call
  end

  def edit
    @accounts = connectable_accounts
  end

  def update
    result = Posts::SavePost.call(
      workspace: current_workspace, dto: build_dto, actor: current_user, post: @post
    )

    if result.success?
      redirect_to after_save_path(result.value), notice: success_notice(result.value)
    else
      @post = result.error
      @accounts = connectable_accounts
      render :edit, status: :unprocessable_content
    end
  end

  def schedule
    result = Publishing::SchedulePost.call(
      post: @post, workspace: current_workspace, actor: current_user
    )

    if result.success?
      redirect_to workspace_post_path(workspace_slug: current_workspace.slug, id: @post),
                  notice: scheduled_notice(@post.reload)
    else
      redirect_to edit_workspace_post_path(workspace_slug: current_workspace.slug, id: @post),
                  alert: schedule_error(result.error)
    end
  end

  def unschedule
    @post.return_to_draft!
    redirect_to edit_workspace_post_path(workspace_slug: current_workspace.slug, id: @post),
                notice: "Moved back to draft. It will not publish."
  end

  def cancel
    @post.cancel!
    AuditEvent.record!(action: "post.cancelled", workspace: current_workspace,
                       actor_user: current_user, auditable: @post)
    redirect_to workspace_calendar_path(workspace_slug: current_workspace.slug),
                notice: "Cancelled."
  end

  def destroy
    @post.destroy!
    AuditEvent.record!(action: "post.deleted", workspace: current_workspace, actor_user: current_user)
    redirect_to workspace_calendar_path(workspace_slug: current_workspace.slug), notice: "Deleted."
  end

  private

  def scheduled_notice(post)
    when_it_goes = post.scheduled_at_local&.strftime("%-d %b at %-l:%M %p")

    if post.publish_reminder?
      "Saved for #{when_it_goes}. Prachar cannot post there yet, so you will get a reminder with the caption ready."
    else
      "Scheduled for #{when_it_goes}."
    end
  end

  # Preflight hands back the issues themselves, so the owner is told what to fix
  # rather than that something is wrong.
  def schedule_error(error)
    case error
    when :no_time then "Choose a date and time before scheduling."
    when :in_the_past then "That time has already passed. Pick a later one."
    when :no_targets then "Choose at least one account to post to."
    when Array then error.map(&:message).uniq.to_sentence
    else "That could not be scheduled."
    end
  end

  # Scoped through the workspace, so another tenant's post id is simply absent.
  def set_post = @post = current_workspace.posts.find(params[:id])

  def connectable_accounts = current_workspace.social_accounts.connected.order(:provider)

  def build_dto
    Posts::PostDto.new(
      **permitted.to_h.symbolize_keys,
      timezone: current_workspace.timezone,
      social_account_ids: Array(params[:social_account_ids])
    )
  end

  def permitted
    params.fetch(:post, {}).permit(
      :caption, :hashtags, :call_to_action, :first_comment, :link_url,
      :location_name, :status, :scheduled_date, :scheduled_time, :media_file
    )
  end

  def after_save_path(post)
    return workspace_calendar_path(workspace_slug: current_workspace.slug) if post.scheduled?

    edit_workspace_post_path(workspace_slug: current_workspace.slug, id: post)
  end

  def success_notice(post)
    post.scheduled? ? "Scheduled for #{post.scheduled_at_local.strftime('%-d %b at %-l:%M %p')}." : "Saved as a draft."
  end
end
