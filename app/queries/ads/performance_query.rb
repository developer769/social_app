module Ads
  # How the money performed.
  #
  # Kept entirely separate from Analytics, and that separation is the point.
  # Paid reach and organic reach are different measurements of different
  # audiences, and adding them produces a number that means nothing: a post
  # seen by 500 followers and boosted to 2,000 strangers did not reach 2,500
  # people, and the overlap is unknowable from outside the platform. So the two
  # are never summed, never averaged together, and never charted on one axis.
  #
  # Within a campaign, a metric the platform does not report stays absent
  # rather than becoming a zero. "LinkedIn does not report reach" and "nobody
  # was reached" are different statements and only one of them is true.
  class PerformanceQuery
    PERIODS = { 30 => "Last 30 days", 90 => "Last 90 days" }.freeze

    Total = Struct.new(:key, :label, :value, :money, :reported_by, :missing_from, :note,
                       keyword_init: true) do
      # Measured by at least one platform. False means nothing reported it, not
      # that the answer was zero.
      def measured? = !value.nil?
      def partial? = missing_from.any?
    end

    Point = Struct.new(:on_date, :spend_minor, :currency, keyword_init: true)

    def initialize(workspace:, days: 30)
      @workspace = workspace
      @days = PERIODS.key?(days) ? days : 30
    end

    attr_reader :days

    def period_label = PERIODS.fetch(@days)
    def since = @since ||= @days.days.ago.to_date

    def campaigns
      @campaigns ||= @workspace.ad_campaigns.includes(:post, :social_account, :ad_metrics)
                               .recent_first.to_a
    end

    def any_campaigns? = campaigns.any?
    def live_campaigns = campaigns.select { |campaign| campaign.status.in?(%w[pending running paused]) }

    def metrics
      @metrics ||= AdMetric.where(ad_campaign_id: campaigns.map(&:id))
                           .where(on_date: since..)
                           .to_a
    end

    # Anything actually reported back. Zero rows means the platforms have told
    # us nothing yet, which is not the same as a campaign that achieved
    # nothing.
    def any_measurements? = metrics.any?

    def totals
      SocialProvider::Catalog::AD_METRICS.map do |key, label|
        field = key == :spend ? :spend_minor : key
        reporting, silent = platforms_split(key)
        values = metrics.filter_map { |metric| metric.public_send(field) }

        # Results across different goals are not one quantity: reach-results
        # and click-results measure different things, so they are withheld
        # rather than added into a figure that looks authoritative.
        withheld = key == :results && mixed_goals?

        Total.new(
          key: key, label: label,
          value: (values.sum unless values.empty? || withheld),
          money: key == :spend,
          reported_by: reporting,
          missing_from: silent,
          note: (result_note if key == :results)
        )
      end
    end

    def spend_by_day
      grouped = metrics.group_by(&:on_date)

      (since..Date.current).map do |date|
        rows = grouped.fetch(date, [])
        Point.new(
          on_date: date,
          spend_minor: rows.filter_map(&:spend_minor).sum,
          currency: rows.first&.currency || @workspace.currency
        )
      end
    end

    def total_spend
      spent = metrics.filter_map(&:spend_minor)
      return if spent.empty?

      Money.new(minor_units: spent.sum, currency: metrics.first.currency)
    end

    # What the owner committed to, which is knowable without any platform
    # reporting back. Useful precisely when nothing has been measured yet.
    def committed_budget
      totals = live_campaigns.filter_map { |campaign| campaign.total_budget_minor }
      return if totals.empty?

      Money.new(minor_units: totals.sum, currency: live_campaigns.first.currency)
    end

    # "Results" means whatever each campaign was aiming at, so the number is
    # meaningless without saying which. A campaign for reach and one for clicks
    # cannot be added, and if they differ the count is not shown as one figure.
    def result_kinds = @result_kinds ||= metrics.filter_map(&:result_kind).uniq

    def mixed_goals? = result_kinds.size > 1

    def result_note
      return if result_kinds.empty?

      mixed_goals? ? "Your campaigns aim at different things, so these cannot be added up" :
        result_kinds.first.humanize.downcase
    end

    # Which of the platforms in play report a given figure, and which do not.
    # Drives the "LinkedIn does not report this" note rather than a zero.
    def platforms_split(metric)
      definitions = campaigns.filter_map { |campaign| SocialProvider::Catalog.find(campaign.provider) }.uniq
      return [ [], [] ] if definitions.empty?

      definitions.partition { |definition| definition.reports?(metric) }
                 .map { |group| group.map(&:name) }
    end

    def available? = SocialProvider::Registry.any_real?
  end
end
