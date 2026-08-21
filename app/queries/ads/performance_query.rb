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

    # ---- Revenue -------------------------------------------------------------
    #
    # Two sources that are never added together, never averaged, and never
    # shown without saying which is which. What a platform measured is a claim
    # about tracked purchases; what the owner counted is a claim about their
    # own till. Blending them would produce a figure less trustworthy than
    # either, and ROAS is the number most likely to make somebody spend more
    # money.

    def measured_revenue
      values = metrics.filter_map(&:conversion_value_minor)
      return if values.empty?

      Money.new(minor_units: values.sum, currency: currency)
    end

    def measured_conversions
      values = metrics.filter_map(&:conversions)
      values.empty? ? nil : values.sum
    end

    def outcomes
      @outcomes ||= AdOutcome.where(ad_campaign_id: campaigns.map(&:id))
                             .where(occurred_on: since..)
                             .includes(:ad_campaign).newest_first.to_a
    end

    def recorded_revenue
      values = outcomes.filter_map(&:revenue_minor)
      return if values.empty?

      Money.new(minor_units: values.sum, currency: currency)
    end

    def recorded_orders
      values = outcomes.filter_map(&:orders)
      values.empty? ? nil : values.sum
    end

    # Computed only when both halves are genuinely known. An unknown treated as
    # zero would put a confident number about money in front of somebody
    # deciding whether to spend more of it.
    def return_on_spend(source)
      revenue = source == :measured ? measured_revenue : recorded_revenue
      spent = total_spend
      return if revenue.nil? || spent.nil? || spent.minor_units.zero?

      (revenue.minor_units.to_f / spent.minor_units).round(2)
    end

    def cost_per_order
      orders = recorded_orders
      spent = total_spend
      return if orders.nil? || orders.zero? || spent.nil?

      Money.new(minor_units: (spent.minor_units.to_f / orders).round, currency: currency)
    end

    # Why the platform figure is missing, in terms the owner can act on. The
    # usual answer is not that the ad failed but that nothing was watching.
    def revenue_tracking_possible?
      campaigns.filter_map { |campaign| SocialProvider::Catalog.find(campaign.provider) }
               .any? { |definition| definition.reports?(:conversion_value) }
    end

    # The accounts in play that a pixel could be attached to.
    def accounts_that_could_track
      campaigns.map(&:social_account).compact.uniq.select(&:reports_revenue?)
    end

    def accounts_tracking = accounts_that_could_track.select(&:conversion_tracking?)
    def accounts_not_tracking = accounts_that_could_track.reject(&:conversion_tracking?)

    # Three genuinely different situations, and collapsing them into
    # "no revenue" would misdescribe two of them:
    #
    #   :untracked   nothing is watching for purchases, which is normal for a
    #                shop with no website and says nothing about the ads.
    #   :waiting     a pixel is connected and has reported nothing back yet.
    #   :reported    figures have arrived.
    def measured_state
      return :reported if measured_revenue.present?
      return :waiting if accounts_tracking.any?

      :untracked
    end

    def currency = @currency ||= campaigns.first&.currency || @workspace.currency

    def available? = SocialProvider::Registry.any_real?
  end
end
