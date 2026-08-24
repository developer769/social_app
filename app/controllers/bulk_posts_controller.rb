# Planning a month of posts in one go.
class BulkPostsController < ApplicationController
  include WorkspaceScoping
  # pluralize lives in the view layer; the flash text is written here.
  include ActionView::Helpers::TextHelper

  # Step one: which styles.
  def new
    @templates = ::Template.published.order(trend_score: :desc, id: :asc).limit(60)
    @format = params[:format_filter].presence_in(%w[image video])
    @templates = @templates.where(media_format: @format) if @format
  end

  # Step two: what each one features, and when they land.
  def edit
    @templates = ::Template.live.where(id: chosen_ids).index_by { |t| t.id.to_s }
    return redirect_to new_workspace_bulk_post_path(**slug), alert: "Choose at least one style." if @templates.empty?

    @ordered = chosen_ids.filter_map { |id| @templates[id] }
    @products = current_workspace.products.active.in_display_order
    @services = current_workspace.services.active.in_display_order
    @plan = Scheduling::MonthPlanner.new(workspace: current_workspace, count: @ordered.size,
                                         starting: params[:starting]).call
    @starting = params[:starting].presence || Date.current.to_s
  end

  def create
    result = Bulk::CreatePosts.call(
      workspace: current_workspace, actor: current_user,
      items: submitted_items, starting: params[:starting]
    )

    if result.success?
      redirect_to workspace_calendar_path(**slug), notice: success_notice(result.value)
    else
      redirect_to new_workspace_bulk_post_path(**slug), alert: failure_message(result.error)
    end
  end

  private

  def slug = { workspace_slug: current_workspace.slug }

  # Blanks are rejected before anything else: an empty checkbox group arrives
  # as [""], which would otherwise be read as one unknown style rather than as
  # nothing chosen.
  def chosen_ids
    Array(params[:template_ids]).map(&:to_s).reject(&:blank?).uniq.first(Bulk::CreatePosts::MAX)
  end

  # One entry per chosen style, in the order they were chosen, so the schedule
  # the owner reviewed is the schedule they get.
  def submitted_items
    subjects = params.fetch(:subjects, {}).to_unsafe_h

    chosen_ids.map do |id|
      type, subject_id = subjects[id].to_s.split(":", 2)
      { template_id: id, subject_type: type, subject_id: subject_id }
    end
  end

  def success_notice(outcome)
    parts = [ "#{pluralize(outcome.count, 'post')} scheduled" ]
    parts << "from #{outcome.plan.first_on.strftime('%-d %b')} to #{outcome.plan.last_on.strftime('%-d %b')}" if outcome.plan.first_on
    notice = "#{parts.join(' ')}."

    if outcome.needing_video.any?
      notice += " #{pluralize(outcome.needing_video.size, 'post')} needs your own video — Prachar cannot make video yet."
    end

    notice
  end

  def failure_message(error)
    case error
    when :nothing_chosen then "Choose at least one style."
    when :unknown_template then "One of those styles is no longer available."
    when :no_slots then "There is no free slot in your posting days. Check Posting preferences."
    else "That batch could not be created."
    end
  end
end
