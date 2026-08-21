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
    PERIODS = { 30 => "Last 30 days", 90 => "Last 90 days", 365 => "Last year" }.freeze

    Point = Struct.new(:starts_on, :count, keyword_init: true)
    PlatformRow = Struct.new(:provider, :name, :published, :not_posted, :failed, keyword_init: true)
    FailureRow = Struct.new(:reason, :count, keyword_init: true)
    SubjectRow = Struct.new(:subject, :count, keyword_init: true)

    def initialize(workspace:, days: 30)
      @workspace = workspace
      @days = PERIODS.key?(days) ? days : 30
    end

    attr_reader :days

    def period_label = PERIODS.fetch(@days)
    def since = @since ||= @days.days.ago.beginning_of_day
    def zone = @workspace.timezone

    # ---- What happened -------------------------------------------------------

    def posts = @posts ||= @workspace.posts.where(created_at: since..).to_a

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
                             .where(post_targets: { created_at: since.. })
                             .includes(:post).to_a
    end

    # ---- Rhythm --------------------------------------------------------------
    # Counted per week from real posts, against the number the owner said they
    # wanted. No projection: weeks that have not happened are not drawn.

    def weekly_activity
      weeks = settled.group_by { |post| (post.published_at || post.reminded_at || post.updated_at).in_time_zone(zone).beginning_of_week.to_date }

      first_week = since.in_time_zone(zone).beginning_of_week.to_date
      last_week = Time.current.in_time_zone(zone).beginning_of_week.to_date

      (first_week..last_week).step(7).map do |week|
        Point.new(starts_on: week, count: weeks.fetch(week, []).size)
      end
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
