module Inbox
  # What Prachar will and will not ever see, per connected platform.
  #
  # Read straight from each provider's declared capabilities. TikTok publishes
  # no comment or message API, so it is listed as never rather than as not yet
  # -- promising it would be a claim no adapter could ever satisfy (spec 30).
  class ReachQuery
    Row = Struct.new(:provider, :name, :handle, :reads, :connected, keyword_init: true) do
      def readable? = reads.any?
      def unreachable? = reads.empty?
    end

    def initialize(workspace:)
      @workspace = workspace
    end

    def rows
      @rows ||= @workspace.social_accounts.connected.order(:provider).map do |account|
        Row.new(
          provider: account.provider,
          name: account.provider_name,
          handle: account.handle,
          connected: !SocialProvider::Registry.mocked?(account.provider),
          reads: readable_kinds(account.capabilities)
        )
      end
    end

    def any_readable? = rows.any?(&:readable?)
    def unreachable = rows.select(&:unreachable?)

    # True only when a real adapter exists for a platform that can be read.
    def live? = rows.any? { |row| row.readable? && row.connected }

    def waiting_on = rows.select { |row| row.readable? && !row.connected }.map(&:name)

    private

    def readable_kinds(capabilities)
      return [] if capabilities.nil?

      kinds = []
      kinds << "Comments" if capabilities.read_comments?
      kinds << "Messages" if capabilities.direct_messages?
      kinds << "Reviews" if capabilities.reviews?
      kinds
    end
  end
end
