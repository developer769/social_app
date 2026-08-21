module Billing
  # What this workspace has actually used against what its plan allows.
  #
  # Every figure is counted from real records. An entitlement whose feature does
  # not exist yet reports as unavailable rather than showing 0 of 30, which
  # would imply a working meter (spec 27).
  class UsageSummary
    Line = Struct.new(:key, :label, :used, :limit, :available, :note, keyword_init: true) do
      def unlimited? = limit.nil?
      def available? = available

      def percentage
        return 0 if unlimited? || limit.to_i.zero?

        [ ((used.to_f / limit) * 100).round, 100 ].min
      end

      def exhausted? = !unlimited? && used >= limit.to_i
    end

    def initialize(workspace:)
      @workspace = workspace
      @subscription = workspace.subscription
    end

    def call
      return [] if @subscription.nil?

      [
        line("social_accounts", "Connected accounts", @workspace.social_accounts.connected.count),
        line("posts_per_month", "Posts this month", posts_this_month),
        line("team_members", "Team members", team_size),
        line("ai_generations_per_month", "Image generations", 0,
             available: FeatureAvailability.live?("ai_generations_per_month"),
             note: "Generation is not connected yet, so nothing has been used.")
      ]
    end

    private

    def line(key, label, used, available: true, note: nil)
      Line.new(key: key, label: label, used: used,
               limit: @subscription.limit_for(key), available: available, note: note)
    end

    def posts_this_month
      zone = ActiveSupport::TimeZone[@workspace.timezone] || Time.zone
      @workspace.posts.where(created_at: zone.now.beginning_of_month..).count
    end

    def team_size
      @workspace.workspace_memberships.where(invitation_status: %w[accepted pending])
                .where.not(membership_status: "removed").count
    end
  end
end
