module Posts
  # The posts shown on the calendar for one period.
  #
  # Takes the workspace as a required argument, so building an unscoped
  # calendar is not expressible (spec 7).
  class CalendarQuery
    VIEWS = %w[month week day agenda].freeze

    Period = Struct.new(:view, :starts_on, :ends_on, :anchor, keyword_init: true) do
      def title(zone)
        case view
        when "day" then anchor.strftime("%-d %B %Y")
        when "week" then "#{starts_on.strftime('%-d %b')} – #{ends_on.strftime('%-d %b %Y')}"
        when "agenda" then "Next 30 days"
        else anchor.strftime("%B %Y")
        end
      end
    end

    def initialize(workspace:, view: "month", date: nil, provider: nil, status: nil)
      @workspace = workspace
      @view = VIEWS.include?(view.to_s) ? view.to_s : "month"
      @date = date
      @provider = provider.presence
      @status = status.presence
    end

    attr_reader :workspace, :view, :provider, :status

    def zone = ActiveSupport::TimeZone[workspace.timezone] || Time.zone

    def anchor
      @anchor ||= parse_date || zone.today
    end

    def period
      @period ||=
        case view
        when "day" then build(anchor, anchor)
        when "week" then build(anchor.beginning_of_week(:sunday), anchor.end_of_week(:sunday))
        when "agenda" then build(zone.today, zone.today + 29.days)
        else build(anchor.beginning_of_month.beginning_of_week(:sunday),
                   anchor.end_of_month.end_of_week(:sunday))
        end
    end

    def posts
      scope = workspace.posts
                       .where.not(status: "cancelled")
                       .scheduled_between(range_start, range_end)
                       .includes(:template, :subject, { post_targets: :social_account },
                                 post_media: { media_asset: { file_attachment: :blob } })
                       .chronological

      scope = scope.for_provider(provider) if provider
      scope = scope.where(status: status) if status

      scope
    end

    # Grouped by the date the workspace would recognise, not by UTC date: a
    # post at 00:30 IST belongs to that day, not to the one before it.
    def posts_by_date
      @posts_by_date ||= posts.group_by { |post| post.scheduled_at.in_time_zone(zone).to_date }
    end

    def days = (period.starts_on..period.ends_on).to_a

    def previous_date
      case view
      when "day" then anchor - 1.day
      when "week" then anchor - 1.week
      else anchor - 1.month
      end
    end

    def next_date
      case view
      when "day" then anchor + 1.day
      when "week" then anchor + 1.week
      else anchor + 1.month
      end
    end

    private

    def build(starts_on, ends_on)
      Period.new(view: view, starts_on: starts_on, ends_on: ends_on, anchor: anchor)
    end

    def range_start = zone.parse(period.starts_on.to_s).beginning_of_day
    def range_end = zone.parse(period.ends_on.to_s).end_of_day

    def parse_date
      return if @date.blank?

      Date.parse(@date.to_s)
    rescue Date::Error
      nil
    end
  end
end
