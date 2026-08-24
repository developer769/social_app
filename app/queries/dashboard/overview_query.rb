module Dashboard
  # What a shop owner needs to see on opening Prachar.
  #
  # Deliberately not a second copy of Analytics. Analytics is the full record,
  # read when somebody goes looking; this answers two questions asked at a
  # glance -- is anything wrong, and what happens next. Anything that is neither
  # belongs on the Analytics page and not here.
  #
  # Every figure is counted from this application's own records. No platform
  # metric appears, because none can be read yet, and an estimate on the first
  # screen would be the worst place of all to put one (spec 22, 27).
  class OverviewQuery
    WINDOW = 30

    # Something the owner can act on. Severity orders the list: a failed post is
    # more urgent than an empty catalog, and both beat a suggestion.
    Attention = Struct.new(:key, :severity, :title, :detail, :action, :path, keyword_init: true) do
      def critical? = severity == :critical
    end

    Figure = Struct.new(:key, :label, :value, :hint, :path, keyword_init: true)

    def initialize(workspace:, user:)
      @workspace = workspace
      @user = user
    end

    attr_reader :workspace

    def slug = { workspace_slug: @workspace.slug }

    # ---- Is anything wrong? --------------------------------------------------

    def attention
      items = []
      items.concat(failed_posts_attention)
      items.concat(connection_attention)
      items.concat(reply_attention)
      items.concat(catalog_attention)
      items.concat(schedule_attention)
      items.sort_by { |item| item.critical? ? 0 : 1 }
    end

    def all_clear? = attention.empty?

    # ---- What happens next --------------------------------------------------

    def upcoming
      @upcoming ||= @workspace.posts.upcoming.includes(:post_targets, post_media: :media_asset)
                              .chronological.limit(5).to_a
    end

    def drafts
      @drafts ||= @workspace.posts.where(status: "draft").order(updated_at: :desc).limit(3).to_a
    end

    # ---- How it is going ----------------------------------------------------

    def analytics
      @analytics ||= Analytics::OverviewQuery.new(workspace: @workspace, days: WINDOW)
    end

    def figures
      [
        Figure.new(key: :published, label: "Went out", value: analytics.counts[:published],
                   hint: "last #{WINDOW} days", path: :analytics),
        Figure.new(key: :scheduled, label: "Lined up", value: scheduled_ahead,
                   hint: "still to come", path: :calendar),
        Figure.new(key: :drafts, label: "In progress", value: draft_count,
                   hint: "not scheduled yet", path: :calendar),
        Figure.new(key: :waiting, label: "Waiting on you", value: awaiting_reply_count,
                   hint: "in the inbox", path: :inbox)
      ]
    end

    def scheduled_ahead
      @scheduled_ahead ||= @workspace.posts.where(status: "scheduled")
                                     .where(scheduled_at: Time.current..).count
    end

    def draft_count = @draft_count ||= @workspace.posts.where(status: "draft").count

    def awaiting_reply_count
      @awaiting_reply_count ||= @workspace.conversations.open.includes(:messages).count(&:awaiting_reply?)
    end

    # ---- What has been happening --------------------------------------------

    def recent_activity
      events = @workspace.audit_events.includes(:actor_user, :auditable).recent_first.limit(12)
      ActivityPresenter.visible_for(events, viewer: @user).first(5)
    end

    # ---- Accounts -----------------------------------------------------------

    def accounts = @accounts ||= @workspace.social_accounts.order(:provider).to_a

    def accounts_needing_attention
      accounts.reject { |account| account.usable_for_publishing? && !account.token_expiring_soon? }
    end

    private

    def failed_posts_attention
      failed = @workspace.posts.where(status: %w[failed partially_published])
                         .where(updated_at: 14.days.ago..).count
      return [] if failed.zero?

      [ Attention.new(
        key: :failed_posts, severity: :critical,
        title: "#{failed} #{'post'.pluralize(failed)} did not go out",
        detail: "Something stopped #{failed == 1 ? 'it' : 'them'} in the last fortnight. The reason is on each post.",
        action: "See what happened", path: :calendar
      ) ]
    end

    def connection_attention
      broken = accounts.reject(&:usable_for_publishing?)
      expiring = accounts.select { |a| a.usable_for_publishing? && a.token_expiring_soon? }
      items = []

      if broken.any?
        items << Attention.new(
          key: :broken_connections, severity: :critical,
          title: "#{broken.map(&:provider_name).to_sentence} needs reconnecting",
          detail: "Nothing can be posted there until it is reconnected.",
          action: "Reconnect", path: :connections
        )
      end

      if expiring.any?
        items << Attention.new(
          key: :expiring_connections, severity: :warning,
          title: "#{expiring.map(&:provider_name).to_sentence} expires soon",
          detail: "Reconnect before it lapses and posts start failing.",
          action: "Reconnect", path: :connections
        )
      end

      items
    end

    def reply_attention
      waiting = awaiting_reply_count
      return [] if waiting.zero?

      [ Attention.new(
        key: :awaiting_reply, severity: :warning,
        title: "#{waiting} #{'person'.pluralize(waiting)} waiting for a reply",
        detail: "Someone wrote and has not heard back.",
        action: "Open the inbox", path: :inbox
      ) ]
    end

    def catalog_attention
      return [] if @workspace.products.active.exists? || @workspace.services.active.exists?

      [ Attention.new(
        key: :empty_catalog, severity: :warning,
        title: "Your catalog is empty",
        detail: "Prachar writes about what you sell, so it needs to know what that is.",
        action: "Add products", path: :catalog
      ) ]
    end

    # Only worth saying once the workspace is actually set up: a brand-new one
    # has nothing scheduled and does not need telling.
    def schedule_attention
      return [] unless @workspace.onboarding_completed?
      return [] if scheduled_ahead.positive?

      [ Attention.new(
        key: :nothing_scheduled, severity: :info,
        title: "Nothing is lined up",
        detail: "There is no post waiting to go out. A quiet week is a choice, but make it a deliberate one.",
        action: "Plan a post", path: :create
      ) ]
    end
  end
end
