module Analytics
  # What Prachar can honestly report about a workspace.
  #
  # Every number here is counted from this application's own records: what was
  # scheduled, what went out, where it went, what stopped it. Not one of them is
  # estimated, projected or modelled (spec 22: do not invent performance
  # claims).
  #
  # Likes, reach, impressions and follower counts are deliberately absent. They
  # live inside the platforms and no adapter is connected to fetch them, so the
  # screen says they are unavailable rather than showing a zero -- a zeroed
  # engagement chart reads as "your posts failed", which is a different and
  # much worse claim than "we cannot see this yet" (the measured-vs-unavailable
  # rule).
  class OverviewQuery
    # No longer offered in the interface, but still honoured: a ?days=90 link
    # shared or bookmarked while the shortcuts existed should still open the
    # window it promised rather than quietly showing a different one.
    PERIODS = { 30 => "Last 30 days", 90 => "Last 90 days", 365 => "Last year" }.freeze

    # Long enough for any honest question, short enough that a typed URL cannot
    # ask the database to group five years of posts by week.
    MAX_SPAN_DAYS = 731

    Point = Struct.new(:starts_on, :count, keyword_init: true)
    PlatformRow = Struct.new(:provider, :name, :published, :not_posted, :failed, keyword_init: true)
    FailureRow = Struct.new(:reason, :count, keyword_init: true)
    SubjectRow = Struct.new(:subject, :count, keyword_init: true)

    # Accepts either a range or one of the shortcut periods. Both end up as a
    # pair of dates, so everything below has one thing to reason about.
    def initialize(workspace:, from: nil, to: nil, days: nil)
      @workspace = workspace
      @zone = workspace.time_zone

      # Today belongs to the workspace, not to the application. config.time_zone
      # is Asia/Kolkata, so Date.current answers for Delhi wherever the
      # workspace actually is -- and capping a date picker with it puts the
      # workspace's own today out of reach.
      @today = workspace.today

      if PERIODS.key?(days.to_i)
        @to = @today
        @from = @today - (days.to_i - 1)
      else
        @to = parse_date(to) || @today
        @from = parse_date(from) || (@to - 29)
      end

      # A range typed backwards is a slip, not a request for nothing.
      @from, @to = @to, @from if @from > @to
      # Nothing has happened tomorrow, so offering it only invites empty charts.
      @to = @today if @to > @today
      @from = @to - (MAX_SPAN_DAYS - 1) if (@to - @from).to_i >= MAX_SPAN_DAYS
    end

    attr_reader :from, :to, :today

    # Inclusive of both ends: 1st to 1st is one day, not zero.
    def days = (@to - @from).to_i + 1

    def period_label
      return "today" if @from == @to && @to == @today
      return I18n.l(@from, format: :long) if @from == @to

      "#{I18n.l(@from, format: :long)} to #{I18n.l(@to, format: :long)}"
    end

    def since = @since ||= @zone.parse(@from.to_s).beginning_of_day
    def until_time = @until_time ||= @zone.parse(@to.to_s).end_of_day
    def zone = @zone

    # ---- What happened -------------------------------------------------------

    def posts = @posts ||= @workspace.posts.where(created_at: since..until_time).to_a

    def counts
      @counts ||= {
        published: settled.count { |post| post.published? || post.partially_published? },
        reminded: settled.count(&:reminded?),
        failed: settled.count(&:failed?),
        scheduled: posts.count(&:scheduled?),
        drafts: posts.count(&:draft?)
      }
    end

    def settled = @settled ||= posts.select(&:settled?)

    def anything_happened? = posts.any?

    # ---- Where it went -------------------------------------------------------

    def by_platform
      grouped = targets.group_by(&:provider)

      SocialProvider::Catalog.keys.filter_map do |provider|
        rows = grouped[provider]
        next if rows.blank?

        PlatformRow.new(
          provider: provider,
          name: SocialProvider::Catalog.find(provider)&.name || provider.humanize,
          published: rows.count(&:published?),
          not_posted: rows.count(&:skipped?),
          failed: rows.count(&:failed?)
        )
      end
    end

    def targets
      @targets ||= PostTarget.joins(:post)
                             .where(posts: { workspace_id: @workspace.id })
                             .where(post_targets: { created_at: since..until_time })
                             .includes(:post).to_a
    end

    # ---- Rhythm --------------------------------------------------------------
    # Counted per week from real posts, against the number the owner said they
    # wanted. No projection: weeks that have not happened are not drawn.

    def weekly_activity
      weeks = settled.group_by { |post| (post.published_at || post.reminded_at || post.updated_at).in_time_zone(zone).beginning_of_week.to_date }

      first_week = @from.beginning_of_week
      last_week = @to.beginning_of_week

      (first_week..last_week).step(7).map do |week|
        Point.new(starts_on: week, count: weeks.fetch(week, []).size)
      end
    end

    # A bad date in a URL is not worth an exception. Falling back to the
    # default window shows something true rather than a 500.
    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    def target_per_week = @workspace.posting_preference&.posts_per_week

    # Averaged over whole weeks only. Counting the current part-week would drag
    # the average down for no reason other than it being Tuesday.
    def complete_weeks = @complete_weeks ||= weekly_activity[0...-1] || []

    def average_per_week
      return 0.0 if complete_weeks.empty?

      (complete_weeks.sum(&:count).to_f / complete_weeks.size).round(1)
    end

    # A workspace whose entire history is this week has no finished week to
    # average, and telling it that it averages 0.0 posts -- while it has posted
    # five times since Monday -- would be arithmetically true and completely
    # wrong. There is nothing to compare yet, so nothing is claimed.
    def enough_history_to_compare?
      target_per_week.present? && complete_weeks.any? { |week| week.count.positive? }
    end

    def this_week_count = weekly_activity.last&.count.to_i

    def keeping_up? = enough_history_to_compare? && average_per_week >= target_per_week

    # ---- What stopped things -------------------------------------------------

    def failure_reasons
      targets.reject { |target| target.published? || target.pending? || target.publishing? }
             .group_by { |target| target.error_message.presence || "No reason recorded" }
             .map { |reason, rows| FailureRow.new(reason: reason, count: rows.size) }
             .sort_by { |row| -row.count }
             .first(6)
    end

    # ---- What has been featured ---------------------------------------------
    # Genuinely useful and entirely ours to know: a shop with eleven products
    # that has only ever posted about two can be told so.

    def featured
      posts.select { |post| post.subject.present? }
           .group_by(&:subject)
           .map { |subject, rows| SubjectRow.new(subject: subject, count: rows.size) }
           .sort_by { |row| -row.count }
    end

    def never_featured
      posted = posts.filter_map { |post| [ post.subject_type, post.subject_id ] if post.subject_id }.to_set

      (@workspace.products.active.to_a + @workspace.services.active.to_a).reject do |item|
        posted.include?([ item.class.name, item.id ])
      end
    end

    # ---- What we cannot see --------------------------------------------------

    # The platforms that WOULD provide engagement figures once an adapter for
    # them exists. Listed by name so the absence is specific rather than a
    # shrug.
    def platforms_awaiting_analytics
      @workspace.social_accounts.connected.select { |account| account.capabilities&.analytics? }
                .reject { |account| SocialProvider::Registry.any_real? }
                .map(&:provider_name).uniq
    end

    def engagement_available? = SocialProvider::Registry.any_real?
  end
end
