module Scheduling
  # Spreads a batch of posts across the days the owner said they want to post.
  #
  # This is arithmetic, not intelligence, and the interface says so. It reads
  # the workspace's own posting preferences -- which days, what time, how many a
  # week -- and walks forward finding free slots. Calling it AI would be a claim
  # about something that does not exist here (spec 22).
  #
  # Times are built in the workspace's timezone and stored with it, so a batch
  # planned in Jaipur stays at 10am in Jaipur whoever later opens it.
  class MonthPlanner
    # Never search further than this. A workspace that posts once a week and
    # asks for fifty posts would otherwise walk a year into the future.
    HORIZON = 120

    # When no preferred days are set. Spread rather than consecutive: three
    # posts in a week should not all land on Monday.
    DEFAULT_DAYS = [ 1, 3, 5 ].freeze

    Plan = Struct.new(:slots, :requested, :horizon_reached, keyword_init: true) do
      def count = slots.size
      def first_on = slots.first&.to_date
      def last_on = slots.last&.to_date
      def short? = slots.size < requested
      def horizon_reached? = horizon_reached
      def spans_days = first_on && last_on ? (last_on - first_on).to_i + 1 : 0
    end

    def initialize(workspace:, count:, starting: nil)
      @workspace = workspace
      @count = count.to_i
      @starting = starting
    end

    def call
      return Plan.new(slots: [], requested: @count, horizon_reached: false) if @count <= 0

      slots = []
      day = start_date
      horizon = start_date + HORIZON
      weekly = Hash.new(0)

      while slots.size < @count && day <= horizon
        if posting_day?(day) && weekly[week_of(day)] < per_week
          at = time_on(day)
          # A slot already holding a scheduled post is not free: two posts at
          # the same minute is a worse outcome than one arriving a day later.
          unless past?(at) || taken?(at)
            slots << at
            weekly[week_of(day)] += 1
          end
        end

        day += 1
      end

      Plan.new(slots: slots, requested: @count, horizon_reached: slots.size < @count)
    end

    private

    def zone = @zone ||= ActiveSupport::TimeZone[@workspace.timezone] || Time.zone

    def preference = @preference ||= @workspace.posting_preference

    def start_date
      @start_date ||= (@starting.presence&.to_date || zone.today)
    end

    def posting_days
      @posting_days ||= begin
        days = Array(preference&.preferred_days).map(&:to_i).select { |d| (0..6).cover?(d) }
        days.presence || DEFAULT_DAYS
      end
    end

    def posting_day?(date) = posting_days.include?(date.wday)

    # Respected so a batch does not quietly overrule the rhythm the owner chose.
    # It only ever slows the batch down; it never drops a post.
    def per_week = @per_week ||= [ preference&.posts_per_week.to_i, 1 ].max

    def week_of(date) = date.strftime("%G-%V")

    def time_on(date)
      hour, minute = (preference&.preferred_time.presence || "10:00").split(":").map(&:to_i)
      zone.local(date.year, date.month, date.day, hour.to_i, minute.to_i)
    end

    def past?(at) = at <= Time.current

    def taken?(at)
      occupied.any? { |existing| (existing - at).abs < 30.minutes }
    end

    def occupied
      @occupied ||= @workspace.posts
                              .where(status: %w[scheduled approved awaiting_approval publishing])
                              .where(scheduled_at: Time.current..(Time.current + HORIZON.days))
                              .pluck(:scheduled_at)
    end
  end
end
