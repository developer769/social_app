module SocialProvider
  # The interface every provider implements. Each method either returns a
  # normalised DTO or raises PermanentError / TransientError, so callers never
  # branch on a provider's own error shapes (spec 30).
  class Adapter
    attr_reader :account

    def initialize(account: nil)
      @account = account
    end

    def key = self.class.name.demodulize.underscore
    def definition = Catalog.find(key)
    def capabilities = definition&.capabilities

    def connect(authorization_code:) = not_implemented(__method__)
    def refresh_authorization = not_implemented(__method__)
    def fetch_profile = not_implemented(__method__)
    def publish(request) = not_implemented(__method__)
    def publication_status(remote_id:) = not_implemented(__method__)
    def fetch_analytics(since:, until_date:) = not_implemented(__method__)
    def fetch_conversations(since:) = not_implemented(__method__)
    def send_reply(conversation:, body:) = not_implemented(__method__)
    def create_campaign(campaign:) = not_implemented(__method__)
    def fetch_campaign_metrics(campaign:, since:) = not_implemented(__method__)

    # Whether purchase figures can be requested for this account. Requesting
    # conversion metrics with no pixel or dataset behind them is an error on
    # every real ad API, so the question is not asked at all.
    def revenue_readable?(account)
      definition&.reports?(:conversion_value).present? && account&.conversion_tracking?
    end

    private

    def not_implemented(name)
      raise NotImplementedError, "#{self.class} must implement ##{name}"
    end

    # Guards a call against a capability the provider does not have, so an
    # unsupported action fails immediately and clearly rather than producing a
    # confusing provider error.
    def require_capability!(flag)
      return if capabilities&.supports?(flag)

      raise PermanentError.new(
        "#{definition&.name || key} does not support #{flag.to_s.humanize.downcase}",
        code: "unsupported_capability"
      )
    end
  end
end
