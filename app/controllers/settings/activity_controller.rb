module Settings
  # What has happened in this workspace, from the audit trail that was already
  # being written for every meaningful action and shown to nobody.
  class ActivityController < BaseController
    PER_PAGE = 40

    def show
      # Paged over the audit rows themselves, not over the visible sentences.
      # Whether a row is visible depends on who is looking, so paging by visible
      # count would make an offset mean different things on different pages and
      # would quietly skip or repeat entries. A page can therefore show fewer
      # than PER_PAGE lines, which is the harmless half of the trade.
      events = current_workspace.audit_events
                                .includes(:actor_user, :auditable)
                                .recent_first
                                .offset(offset)
                                .limit(PER_PAGE)
                                .to_a

      @entries = ActivityPresenter.visible_for(events, viewer: current_user)
      @page = page
      @more = events.size == PER_PAGE
      @total = current_workspace.audit_events.count
    end

    private

    def page = @page_number ||= [ params[:page].to_i, 1 ].max
    def offset = (page - 1) * PER_PAGE
  end
end
